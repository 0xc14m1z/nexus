defmodule Nexus.TranscriptStores.InMemory do
  @moduledoc """
  ETS-backed in-memory implementation of `Nexus.TranscriptStore`.
  """

  @behaviour Nexus.TranscriptStore

  alias Nexus.Message

  @table :nexus_transcript_store

  defguardp is_transcript_message(message)
            when is_struct(message, Message.Transcript.User) or
                   is_struct(message, Message.Transcript.Assistant) or
                   is_struct(message, Message.Transcript.AssistantToolCall) or
                   is_struct(message, Message.Transcript.Tool)

  @doc """
  Clears all persisted messages. Intended for tests.
  """
  @spec clear(map()) :: true
  def clear(config \\ %{}) do
    ensure_table(config)
    :ets.delete_all_objects(@table)
  end

  @impl true
  def append(message, config) when is_transcript_message(message) and is_map(config) do
    ensure_table(config)

    persisted_message = persistable_message(message)

    :ets.insert(@table, {persisted_message.id, persisted_message})

    {:ok, persisted_message}
  end

  def append(message) when is_transcript_message(message), do: append(message, %{})

  @impl true
  def list_by_session(session_id, config) when is_binary(session_id) and is_map(config) do
    ensure_table(config)

    messages =
      @table
      |> :ets.tab2list()
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(&1.session_id == session_id))
      |> Enum.sort_by(&DateTime.to_unix(&1.inserted_at, :microsecond))

    {:ok, messages}
  end

  def list_by_session(session_id) when is_binary(session_id), do: list_by_session(session_id, %{})

  # Transcript messages may already carry ids or timestamps, but the store
  # fills them in when missing so append semantics stay convenient.
  defp persistable_message(message) when is_transcript_message(message) do
    now = DateTime.utc_now()

    struct(message, %{
      id: Map.get(message, :id) || build_id(),
      inserted_at: Map.get(message, :inserted_at) || now
    })
  end

  # The in-memory transcript adapter uses a simple monotonic id because the only
  # immediate requirement is stable identity within one local runtime.
  defp build_id do
    "message_" <> Integer.to_string(System.unique_integer([:positive]))
  end

  # The in-memory adapter ignores config today, but it accepts it so callers
  # can treat all transcript stores uniformly.
  defp ensure_table(_config) do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set])

      _table ->
        @table
    end
  end
end
