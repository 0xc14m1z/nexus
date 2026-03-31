defmodule Nexus.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore
  alias Nexus.Orchestrator
  alias Nexus.Providers.Fake
  alias Nexus.Session
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    InMemoryTranscriptStore.clear()
    :ok
  end

  test "run/4 creates a session through the store when the inbound message has no session id" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory, InMemoryTranscriptStore)
    assert is_binary(outbound.session_id)
    assert {:ok, %Session{id: id}} = InMemory.get(outbound.session_id)
    assert id == outbound.session_id
  end

  test "run/4 reuses an existing session from the store" do
    assert {:ok, %Session{id: session_id}} = InMemory.save(%Session{})

    inbound = %Message.Inbound{
      session_id: session_id,
      channel: :cli,
      content: "hello again",
      metadata: %{}
    }

    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory, InMemoryTranscriptStore)
    assert outbound.session_id == session_id
  end

  test "run/4 persists the user and assistant transcript messages" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory, InMemoryTranscriptStore)
    assert {:ok, messages} = InMemoryTranscriptStore.list_by_session(outbound.session_id)

    assert [
             %Message.Transcript.User{content: "hello nexus"},
             %Message.Transcript.Assistant{
               content:
                 "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus"
             }
           ] = messages
  end

  test "run/4 builds the next turn from the existing session transcript" do
    first_inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, first_outbound} =
             Orchestrator.run(first_inbound, Fake, InMemory, InMemoryTranscriptStore)

    second_inbound = %Message.Inbound{
      session_id: first_outbound.session_id,
      channel: :cli,
      content: "continue",
      metadata: %{}
    }

    assert {:ok, second_outbound} =
             Orchestrator.run(second_inbound, Fake, InMemory, InMemoryTranscriptStore)

    assert second_outbound.content =~ "User:\nhello nexus"
    assert second_outbound.content =~ "Assistant:\nFake response: System:"
    assert second_outbound.content =~ "User:\ncontinue"
  end

  test "run/4 returns an error when the requested session does not exist" do
    inbound = %Message.Inbound{
      session_id: "session_missing",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :session_not_found} =
             Orchestrator.run(inbound, Fake, InMemory, InMemoryTranscriptStore)
  end

  test "run/4 returns an invalid session store error for a module that is not a session store" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, {:invalid_session_store, String}} =
             Orchestrator.run(inbound, Fake, String, InMemoryTranscriptStore)
  end

  test "run/4 returns an invalid transcript store error for a module that is not a transcript store" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, {:invalid_transcript_store, String}} =
             Orchestrator.run(inbound, Fake, InMemory, String)
  end
end
