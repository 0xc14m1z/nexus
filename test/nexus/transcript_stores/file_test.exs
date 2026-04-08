defmodule Nexus.TranscriptStores.FileTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.TranscriptStores.File, as: FileStore

  setup do
    directory =
      Path.join(System.tmp_dir!(), "nexus-transcript-store-#{System.unique_integer([:positive])}")

    config = %{directory: directory}

    on_exit(fn -> File.rm_rf(directory) end)

    {:ok, config: config}
  end

  test "append/2 assigns id and inserted_at when missing", %{config: config} do
    message = %Message.Transcript.User{
      session_id: "session_123",
      content: "hello"
    }

    assert {:ok, persisted_message} = FileStore.append(message, config)
    assert is_binary(persisted_message.id)
    assert %DateTime{} = persisted_message.inserted_at
    assert File.exists?(Path.join(config.directory, "session_123.jsonl"))
  end

  test "list_by_session/2 returns messages ordered from oldest to newest", %{config: config} do
    older = ~U[2026-03-28 10:00:00Z]
    newer = ~U[2026-03-28 10:05:00Z]

    FileStore.append(
      %Message.Transcript.Assistant{
        session_id: "session_123",
        content: "second",
        inserted_at: newer
      },
      config
    )

    FileStore.append(
      %Message.Transcript.User{
        session_id: "session_123",
        content: "first",
        inserted_at: older
      },
      config
    )

    FileStore.append(
      %Message.Transcript.User{
        session_id: "session_other",
        content: "other"
      },
      config
    )

    assert {:ok, messages} = FileStore.list_by_session("session_123", config)

    assert Enum.map(messages, & &1.content) == ["first", "second"]
  end

  test "append/2 preserves tool-related transcript fields", %{config: config} do
    message = %Message.Transcript.Tool{
      session_id: "session_123",
      content: "search results",
      tool_call_id: "call_123",
      name: "web_search"
    }

    assert {:ok, persisted_message} = FileStore.append(message, config)
    assert {:ok, [loaded_message]} = FileStore.list_by_session("session_123", config)

    assert persisted_message.tool_call_id == "call_123"
    assert persisted_message.name == "web_search"
    assert loaded_message.tool_call_id == "call_123"
    assert loaded_message.name == "web_search"
    assert loaded_message.content == "search results"
  end

  test "list_by_session/2 returns an empty list when the transcript file does not exist", %{
    config: config
  } do
    assert {:ok, []} = FileStore.list_by_session("session_missing", config)
  end
end
