defmodule Nexus.SessionStoreInstanceTest do
  use ExUnit.Case, async: false

  alias Nexus.Session
  alias Nexus.SessionStoreInstance
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "new/2 builds a session store instance from a valid adapter" do
    assert {:ok, %SessionStoreInstance{adapter: InMemory, config: %{mode: :test}}} =
             SessionStoreInstance.new(InMemory, %{mode: :test})
  end

  test "new/2 rejects an adapter that does not implement the session store behaviour" do
    assert {:error, {:invalid_session_store, String}} = SessionStoreInstance.new(String, %{})
  end

  test "save/2 and get/2 delegate to the configured adapter" do
    store = %SessionStoreInstance{adapter: InMemory, config: %{}}

    assert {:ok, %Session{id: session_id} = session} =
             SessionStoreInstance.save(store, %Session{})

    assert {:ok, loaded_session} = SessionStoreInstance.get(store, session_id)

    assert loaded_session == session
  end
end
