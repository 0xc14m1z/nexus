defmodule Nexus.SessionStores.InMemoryTest do
  use ExUnit.Case, async: false

  alias Nexus.Session
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "save/1 assigns id and timestamps when they are missing" do
    assert {:ok, %Session{} = session} = InMemory.save(%Session{})

    assert is_binary(session.id)
    assert String.starts_with?(session.id, "session_")
    assert %DateTime{} = session.created_at
    assert %DateTime{} = session.updated_at
  end

  test "get/1 returns a previously saved session" do
    input = %Session{id: "session_123"}

    assert {:ok, %Session{} = saved_session} = InMemory.save(input)
    assert {:ok, loaded_session} = InMemory.get("session_123")

    assert loaded_session == saved_session
    assert loaded_session.id == "session_123"
  end
end
