defmodule Nexus.MessageStores.InMemoryTest do
  use ExUnit.Case, async: false

  alias Nexus.MessageStores.InMemory
  alias Nexus.SessionMessage

  setup do
    InMemory.clear()
    :ok
  end

  test "append/1 assigns id and inserted_at when missing" do
    message = %SessionMessage{
      session_id: "session_123",
      role: :user,
      content: "hello"
    }

    assert {:ok, persisted_message} = InMemory.append(message)
    assert is_binary(persisted_message.id)
    assert %DateTime{} = persisted_message.inserted_at
  end

  test "list_by_session/1 returns messages ordered from oldest to newest" do
    older = ~U[2026-03-28 10:00:00Z]
    newer = ~U[2026-03-28 10:05:00Z]

    InMemory.append(%SessionMessage{
      session_id: "session_123",
      role: :assistant,
      content: "second",
      inserted_at: newer
    })

    InMemory.append(%SessionMessage{
      session_id: "session_123",
      role: :user,
      content: "first",
      inserted_at: older
    })

    InMemory.append(%SessionMessage{
      session_id: "session_other",
      role: :user,
      content: "other"
    })

    assert {:ok, messages} = InMemory.list_by_session("session_123")

    assert Enum.map(messages, & &1.content) == ["first", "second"]
  end
end
