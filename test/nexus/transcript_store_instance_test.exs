defmodule Nexus.TranscriptStoreInstanceTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.TranscriptStoreInstance
  alias Nexus.TranscriptStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "new/2 builds a transcript store instance from a valid adapter" do
    assert {:ok, %TranscriptStoreInstance{adapter: InMemory, config: %{mode: :test}}} =
             TranscriptStoreInstance.new(InMemory, %{mode: :test})
  end

  test "new/2 rejects an adapter that does not implement the transcript store behaviour" do
    assert {:error, {:invalid_transcript_store, String}} =
             TranscriptStoreInstance.new(String, %{})
  end

  test "append/2 and list_by_session/2 delegate to the configured adapter" do
    store = %TranscriptStoreInstance{adapter: InMemory, config: %{}}

    message = %Message.Transcript.User{
      session_id: "session_123",
      content: "hello"
    }

    assert {:ok, _persisted} = TranscriptStoreInstance.append(store, message)

    assert {:ok, [%Message.Transcript.User{content: "hello"}]} =
             TranscriptStoreInstance.list_by_session(store, "session_123")
  end
end
