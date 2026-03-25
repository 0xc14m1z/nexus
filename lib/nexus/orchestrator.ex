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
  alias Nexus.Message.Inbound
  alias Nexus.Message.Outbound
  alias Nexus.Session

  @doc """
  Resolves or creates the session for an inbound message and executes one agent turn.
  """
  @spec run(Inbound.t(), module(), module()) :: {:ok, Outbound.t()} | {:error, term()}
  def run(%Inbound{} = inbound, provider, session_store) do
    with :ok <- AdapterValidator.validate_session_store(session_store),
         {:ok, session} <- resolve_session(inbound.session_id, session_store) do
      inbound
      |> Map.put(:session_id, session.id)
      |> AgentLoop.run(provider)
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
end
