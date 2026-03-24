defmodule Nexus.SessionStores.InMemory do
  @moduledoc """
  In-memory `SessionStore` adapter backed by ETS.

  This adapter exists to make the contract executable with the smallest
  possible amount of infrastructure.
  """

  @behaviour Nexus.SessionStore

  alias Nexus.Session

  @table :nexus_session_store

  @doc """
  Clears all stored sessions.

  This helper is mainly useful in tests.
  """
  @spec clear() :: :ok
  def clear do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def get(session_id) when is_binary(session_id) do
    ensure_table()

    case :ets.lookup(@table, session_id) do
      [{^session_id, session}] -> {:ok, session}
      [] -> :not_found
    end
  end

  @impl true
  def save(%Session{} = session) do
    ensure_table()

    now = DateTime.utc_now()

    persisted_session =
      session
      |> ensure_id()
      |> ensure_created_at(now)
      |> Map.put(:updated_at, now)

    true = :ets.insert(@table, {persisted_session.id, persisted_session})

    {:ok, persisted_session}
  end

  defp ensure_id(%Session{id: id} = session) when is_binary(id), do: session

  defp ensure_id(%Session{} = session) do
    %{
      session
      | id: "session_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
    }
  end

  defp ensure_created_at(%Session{created_at: nil} = session, now) do
    %{session | created_at: now}
  end

  defp ensure_created_at(%Session{} = session, _now), do: session

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set])
        rescue
          ArgumentError -> @table
        end

      _table ->
        @table
    end

    :ok
  end
end
