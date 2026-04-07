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
  @spec clear(map()) :: :ok
  def clear(config \\ %{}) do
    ensure_table(config)
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def get(session_id, config) when is_binary(session_id) and is_map(config) do
    ensure_table(config)

    case :ets.lookup(@table, session_id) do
      [{^session_id, session}] -> {:ok, session}
      [] -> :not_found
    end
  end

  def get(session_id) when is_binary(session_id), do: get(session_id, %{})

  @impl true
  def save(%Session{} = session, config) when is_map(config) do
    ensure_table(config)

    now = DateTime.utc_now()

    persisted_session =
      session
      |> ensure_id()
      |> ensure_created_at(now)
      |> Map.put(:updated_at, now)

    true = :ets.insert(@table, {persisted_session.id, persisted_session})

    {:ok, persisted_session}
  end

  def save(%Session{} = session), do: save(session, %{})

  # Existing sessions keep their assigned id, while brand new sessions get a
  # simple monotonic identifier from the in-memory adapter.
  defp ensure_id(%Session{id: id} = session) when is_binary(id), do: session

  defp ensure_id(%Session{} = session) do
    %{
      session
      | id: "session_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
    }
  end

  # `created_at` is assigned only once so repeated saves behave like updates.
  defp ensure_created_at(%Session{created_at: nil} = session, now) do
    %{session | created_at: now}
  end

  defp ensure_created_at(%Session{} = session, _now), do: session

  # The in-memory adapter ignores config today, but it keeps the argument so it
  # can participate in the same runtime configuration flow as file-backed stores.
  defp ensure_table(_config) do
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
