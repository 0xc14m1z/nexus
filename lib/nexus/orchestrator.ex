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
  alias Nexus.Session

  @doc """
  Resolves or creates the session for an inbound message and executes one agent turn.
  """
  @spec run(Message.Inbound.t(), module(), module(), module()) ::
          {:ok, Message.Outbound.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound, provider, session_store, transcript_store) do
    with :ok <- AdapterValidator.validate_session_store(session_store),
         :ok <- AdapterValidator.validate_transcript_store(transcript_store),
         {:ok, session} <- resolve_session(inbound.session_id, session_store) do
      inbound = Map.put(inbound, :session_id, session.id)

      with {:ok, _message} <- append_user_message(inbound, transcript_store),
           {:ok, result} <- AgentLoop.run(inbound, provider),
           :ok <- append_transcript_messages(result.transcript_messages, transcript_store) do
        {:ok, result.outbound}
      end
    end
  end

  defp resolve_session(nil, session_store) do
    session_store.save(%Session{})
  end

  defp resolve_session(session_id, session_store) when is_binary(session_id) do
    case session_store.get(session_id) do
      {:ok, session} -> {:ok, session}
      :not_found -> {:error, :session_not_found}
    end
  end

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

  defp append_transcript_messages(messages, transcript_store) when is_list(messages) do
    Enum.reduce_while(messages, :ok, fn message, :ok ->
      case transcript_store.append(message) do
        {:ok, _persisted} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
