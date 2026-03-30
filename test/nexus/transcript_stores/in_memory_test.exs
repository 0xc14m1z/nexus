defmodule Nexus.TranscriptStores.InMemoryTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.TranscriptStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "append/1 assigns id and inserted_at when missing" do
    message = %Message.Transcript.User{
      session_id: "session_123",
      content: "hello"
    }

    assert {:ok, persisted_message} = InMemory.append(message)
    assert is_binary(persisted_message.id)
    assert %DateTime{} = persisted_message.inserted_at
  end

  test "list_by_session/1 returns messages ordered from oldest to newest" do
    older = ~U[2026-03-28 10:00:00Z]
    newer = ~U[2026-03-28 10:05:00Z]

    InMemory.append(%Message.Transcript.Assistant{
      session_id: "session_123",
      content: "second",
      inserted_at: newer
    })

    InMemory.append(%Message.Transcript.User{
      session_id: "session_123",
      content: "first",
      inserted_at: older
    })

    InMemory.append(%Message.Transcript.User{
      session_id: "session_other",
      content: "other"
    })

    assert {:ok, messages} = InMemory.list_by_session("session_123")

    assert Enum.map(messages, & &1.content) == ["first", "second"]
  end

  test "append/1 preserves tool-related transcript fields" do
    message = %Message.Transcript.Tool{
      session_id: "session_123",
      content: "search results",
      tool_call_id: "call_123",
      name: "web_search"
    }

    assert {:ok, persisted_message} = InMemory.append(message)

    assert persisted_message.tool_call_id == "call_123"
    assert persisted_message.name == "web_search"
    assert persisted_message.content == "search results"
  end
end
