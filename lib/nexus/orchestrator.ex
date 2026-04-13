defmodule Nexus.Orchestrator do
  @moduledoc """
  Minimal synchronous orchestrator.

  This first version coordinates two things:

  - session resolution through a `SessionStore`
  - delegation of the actual turn execution to `AgentLoop`

  It is intentionally small and does not yet manage processes, routing, or
  concurrent sessions.
  """

  alias Nexus.AgentLoop
  alias Nexus.Message
  alias Nexus.ProviderInstance
  alias Nexus.Session
  alias Nexus.SessionStoreInstance
  alias Nexus.ToolInstance
  alias Nexus.TranscriptStoreInstance

  @doc """
  Resolves or creates the session for an inbound message and executes one agent turn.
  """
  @spec run(
          Message.Inbound.t(),
          ProviderInstance.t(),
          SessionStoreInstance.t(),
          TranscriptStoreInstance.t(),
          [ToolInstance.t()]
        ) ::
          {:ok, Message.Outbound.t()} | {:error, term()}
  def run(
        %Message.Inbound{} = inbound,
        %ProviderInstance{} = provider,
        %SessionStoreInstance{} = session_store,
        %TranscriptStoreInstance{} = transcript_store,
        tool_instances
      ) do
    with :ok <- validate_tool_instances(tool_instances),
         {:ok, session} <- resolve_session(inbound.session_id, session_store) do
      inbound = Map.put(inbound, :session_id, session.id)

      with {:ok, _message} <- append_user_message(inbound, transcript_store),
           {:ok, transcript_messages} <-
             TranscriptStoreInstance.list_by_session(transcript_store, session.id),
           {:ok, result} <-
             AgentLoop.run(session.id, transcript_messages, provider, tool_instances),
           :ok <- append_transcript_messages(result.transcript_messages, transcript_store) do
        {:ok,
         %Message.Outbound{
           session_id: session.id,
           channel: inbound.channel,
           content: result.assistant_content,
           metadata:
             build_outbound_metadata(
               session,
               provider,
               session_store,
               transcript_store,
               tool_instances,
               transcript_messages,
               result
             )
         }}
      end
    end
  end

  def run(%Message.Inbound{}, provider, session_store, transcript_store, tool_instances) do
    cond do
      not match?(%ProviderInstance{}, provider) ->
        {:error, {:invalid_provider_reference, provider}}

      not match?(%SessionStoreInstance{}, session_store) ->
        {:error, {:invalid_session_store_reference, session_store}}

      not match?(%TranscriptStoreInstance{}, transcript_store) ->
        {:error, {:invalid_transcript_store_reference, transcript_store}}

      not is_list(tool_instances) ->
        {:error, {:invalid_tool_instances_reference, tool_instances}}
    end
  end

  defp resolve_session(nil, session_store) do
    SessionStoreInstance.save(session_store, %Session{})
  end

  # When the caller already provides a session id, the orchestrator must reuse
  # that exact session instead of silently creating a new one.
  defp resolve_session(session_id, session_store) when is_binary(session_id) do
    case SessionStoreInstance.get(session_store, session_id) do
      {:ok, session} -> {:ok, session}
      :not_found -> {:error, :session_not_found}
    end
  end

  # The inbound message belongs to the transport boundary, so we translate it
  # into the canonical persisted transcript shape before the agent loop runs.
  defp append_user_message(
         %Message.Inbound{session_id: session_id, content: content},
         transcript_store
       )
       when is_binary(content) do
    TranscriptStoreInstance.append(transcript_store, %Message.Transcript.User{
      session_id: session_id,
      content: content
    })
  end

  defp append_user_message(%Message.Inbound{}, _transcript_store) do
    {:error, :unsupported_inbound_content_for_transcript}
  end

  # The agent loop can produce one or more transcript items for a turn. The
  # orchestrator persists them in order and stops at the first store error.
  defp append_transcript_messages(messages, transcript_store) when is_list(messages) do
    Enum.reduce_while(messages, :ok, fn message, :ok ->
      case TranscriptStoreInstance.append(transcript_store, message) do
        {:ok, _persisted} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_outbound_metadata(
         session,
         provider,
         session_store,
         transcript_store,
         tool_instances,
         transcript_messages,
         result
       ) do
    %{
      debug: %{
        session_id: session.id,
        provider: summarize_instance(provider),
        session_store: summarize_instance(session_store),
        transcript_store: summarize_instance(transcript_store),
        available_tools: summarize_tool_instances(tool_instances),
        transcript_message_count: length(transcript_messages),
        llm_messages: result.llm_messages
      }
    }
  end

  # Runtime instances all expose the same `adapter + config` shape, so a single
  # summarizer keeps debug output consistent across providers and stores.
  defp summarize_instance(%{adapter: adapter, config: config}) do
    %{
      adapter: inspect(adapter),
      config: sanitize_config(config)
    }
  end

  # Debug output should help understand the runtime without leaking secrets or
  # dumping unreadable function references into the terminal.
  defp sanitize_config(config) when is_map(config) do
    Map.new(config, fn {key, value} ->
      {key, sanitize_config_entry(key, value)}
    end)
  end

  defp sanitize_config(other), do: other

  defp sanitize_config_entry(key, _value) when key in [:api_key, "api_key"] do
    "[REDACTED]"
  end

  defp sanitize_config_entry(_key, value) when is_function(value) do
    "[FUNCTION]"
  end

  defp sanitize_config_entry(_key, value) when is_map(value) do
    sanitize_config(value)
  end

  defp sanitize_config_entry(_key, value) when is_list(value) do
    Enum.map(value, fn
      entry when is_map(entry) -> sanitize_config(entry)
      entry when is_function(entry) -> "[FUNCTION]"
      entry -> entry
    end)
  end

  defp sanitize_config_entry(_key, value), do: value

  defp validate_tool_instances(tool_instances) when is_list(tool_instances), do: :ok

  defp validate_tool_instances(tool_instances),
    do: {:error, {:invalid_tool_instances_reference, tool_instances}}

  # Tool debug output stays small on purpose: at this stage we mostly want to
  # know which tool names were visible to the provider for a given turn.
  defp summarize_tool_instances(tool_instances) when is_list(tool_instances) do
    Enum.map(tool_instances, fn
      %ToolInstance{} = tool_instance ->
        tool_instance
        |> ToolInstance.definition()
        |> Map.get(:name)

      _other ->
        "[INVALID TOOL INSTANCE]"
    end)
  end
end
