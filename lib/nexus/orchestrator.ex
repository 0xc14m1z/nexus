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
  alias Nexus.AdapterValidator
  alias Nexus.Message
  alias Nexus.ProviderInstance
  alias Nexus.Session

  @doc """
  Resolves or creates the session for an inbound message and executes one agent turn.
  """
  @spec run(Message.Inbound.t(), {module(), Nexus.Provider.config()}, module(), module()) ::
          {:ok, Message.Outbound.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound, provider, session_store, transcript_store) do
    with :ok <- AdapterValidator.validate_session_store(session_store),
         :ok <- AdapterValidator.validate_transcript_store(transcript_store),
         {:ok, provider} <- build_provider(provider),
         {:ok, session} <- resolve_session(inbound.session_id, session_store) do
      inbound = Map.put(inbound, :session_id, session.id)

      with {:ok, _message} <- append_user_message(inbound, transcript_store),
           {:ok, transcript_messages} <- transcript_store.list_by_session(session.id),
           {:ok, result} <- AgentLoop.run(session.id, transcript_messages, provider),
           :ok <- append_transcript_messages(result.transcript_messages, transcript_store) do
        {:ok,
         %Message.Outbound{
           session_id: session.id,
           channel: inbound.channel,
           content: result.assistant_content,
           metadata: %{}
         }}
      end
    end
  end

  defp build_provider({adapter, config}) when is_map(config) do
    ProviderInstance.new(adapter, config)
  end

  defp build_provider(provider) do
    {:error, {:invalid_provider_reference, provider}}
  end

  defp resolve_session(nil, session_store) do
    session_store.save(%Session{})
  end

  # When the caller already provides a session id, the orchestrator must reuse
  # that exact session instead of silently creating a new one.
  defp resolve_session(session_id, session_store) when is_binary(session_id) do
    case session_store.get(session_id) do
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
    transcript_store.append(%Message.Transcript.User{
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
      case transcript_store.append(message) do
        {:ok, _persisted} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
