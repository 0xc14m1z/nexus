defmodule Nexus.TranscriptStores.InMemory do
  @moduledoc """
  ETS-backed in-memory implementation of `Nexus.TranscriptStore`.
  """

  @behaviour Nexus.TranscriptStore

  alias Nexus.Message

  @table :nexus_transcript_store

  @doc """
  Clears all persisted messages. Intended for tests.
  """
  @spec clear() :: true
  def clear do
    ensure_table()
    :ets.delete_all_objects(@table)
  end

  @impl true
  def append(%Message.Transcript{} = message) do
    ensure_table()

    persisted_message = persistable_message(message)

    :ets.insert(@table, {persisted_message.id, persisted_message})

    {:ok, persisted_message}
  end

  @impl true
  def list_by_session(session_id) when is_binary(session_id) do
    ensure_table()

    messages =
      @table
      |> :ets.tab2list()
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(&1.session_id == session_id))
      |> Enum.sort_by(&DateTime.to_unix(&1.inserted_at, :microsecond))

    {:ok, messages}
  end

  defp persistable_message(%Message.Transcript{} = message) do
    now = DateTime.utc_now()

    %Message.Transcript{
      message
      | id: message.id || build_id(),
        inserted_at: message.inserted_at || now
    }
  end

  defp build_id do
    "message_" <> Integer.to_string(System.unique_integer([:positive]))
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])

      _table ->
        @table
    end
  end
end
