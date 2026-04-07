defmodule Nexus.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.ProviderInstance
  alias Nexus.Orchestrator
  alias Nexus.Providers.Fake
  alias Nexus.Session
  alias Nexus.SessionStoreInstance
  alias Nexus.SessionStores.InMemory
  alias Nexus.TranscriptStoreInstance
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  setup do
    InMemory.clear()
    InMemoryTranscriptStore.clear()

    {:ok, provider} = ProviderInstance.new(Fake, %{})
    {:ok, session_store} = SessionStoreInstance.new(InMemory, %{})
    {:ok, transcript_store} = TranscriptStoreInstance.new(InMemoryTranscriptStore, %{})

    {:ok, provider: provider, session_store: session_store, transcript_store: transcript_store}
  end

  test "run/4 creates a session through the store when the inbound message has no session id", %{
    provider: provider,
    session_store: session_store,
    transcript_store: transcript_store
  } do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, outbound} =
             Orchestrator.run(inbound, provider, session_store, transcript_store)

    assert is_binary(outbound.session_id)
    assert {:ok, %Session{id: id}} = InMemory.get(outbound.session_id)
    assert id == outbound.session_id
  end

  test "run/4 reuses an existing session from the store", %{
    provider: provider,
    session_store: session_store,
    transcript_store: transcript_store
  } do
    assert {:ok, %Session{id: session_id}} = InMemory.save(%Session{})

    inbound = %Message.Inbound{
      session_id: session_id,
      channel: :cli,
      content: "hello again",
      metadata: %{}
    }

    assert {:ok, outbound} =
             Orchestrator.run(inbound, provider, session_store, transcript_store)

    assert outbound.session_id == session_id
  end

  test "run/4 persists the user and assistant transcript messages", %{
    provider: provider,
    session_store: session_store,
    transcript_store: transcript_store
  } do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, outbound} =
             Orchestrator.run(inbound, provider, session_store, transcript_store)

    assert {:ok, messages} = InMemoryTranscriptStore.list_by_session(outbound.session_id)

    assert [
             %Message.Transcript.User{content: "hello nexus"},
             %Message.Transcript.Assistant{
               content:
                 "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus"
             }
           ] = messages
  end

  test "run/4 builds the next turn from the existing session transcript", %{
    provider: provider,
    session_store: session_store,
    transcript_store: transcript_store
  } do
    first_inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, first_outbound} =
             Orchestrator.run(first_inbound, provider, session_store, transcript_store)

    second_inbound = %Message.Inbound{
      session_id: first_outbound.session_id,
      channel: :cli,
      content: "continue",
      metadata: %{}
    }

    assert {:ok, second_outbound} =
             Orchestrator.run(second_inbound, provider, session_store, transcript_store)

    assert second_outbound.content =~ "User:\nhello nexus"
    assert second_outbound.content =~ "Assistant:\nFake response: System:"
    assert second_outbound.content =~ "User:\ncontinue"
  end

  test "run/4 returns an error when the requested session does not exist", %{
    provider: provider,
    session_store: session_store,
    transcript_store: transcript_store
  } do
    inbound = %Message.Inbound{
      session_id: "session_missing",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :session_not_found} =
             Orchestrator.run(inbound, provider, session_store, transcript_store)
  end

  test "run/4 returns an invalid provider reference error when the provider is not a provider instance" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, {:invalid_provider_reference, Fake}} =
             Orchestrator.run(inbound, Fake, :invalid, :invalid)
  end

  test "run/4 returns an invalid session store error for a value that is not a session store instance" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    {:ok, provider} = ProviderInstance.new(Fake, %{})
    {:ok, transcript_store} = TranscriptStoreInstance.new(InMemoryTranscriptStore, %{})

    assert {:error, {:invalid_session_store_reference, String}} =
             Orchestrator.run(inbound, provider, String, transcript_store)
  end

  test "run/4 returns an invalid transcript store error for a value that is not a transcript store instance" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    {:ok, provider} = ProviderInstance.new(Fake, %{})
    {:ok, session_store} = SessionStoreInstance.new(InMemory, %{})

    assert {:error, {:invalid_transcript_store_reference, String}} =
             Orchestrator.run(inbound, provider, session_store, String)
  end
end
