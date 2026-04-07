defmodule NexusTest do
  use ExUnit.Case

  alias Nexus
  alias Nexus.Message
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory, as: InMemorySessionStore
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  setup do
    previous_config = Application.get_env(:nexus, :provider)
    previous_session_store = Application.get_env(:nexus, :session_store)
    previous_transcript_store = Application.get_env(:nexus, :transcript_store)

    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})
    Application.put_env(:nexus, :session_store, adapter: InMemorySessionStore, config: %{})
    Application.put_env(:nexus, :transcript_store, adapter: InMemoryTranscriptStore, config: %{})
    InMemorySessionStore.clear()
    InMemoryTranscriptStore.clear()

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:nexus, :provider)
      else
        Application.put_env(:nexus, :provider, previous_config)
      end

      if previous_session_store == nil do
        Application.delete_env(:nexus, :session_store)
      else
        Application.put_env(:nexus, :session_store, previous_session_store)
      end

      if previous_transcript_store == nil do
        Application.delete_env(:nexus, :transcript_store)
      else
        Application.put_env(:nexus, :transcript_store, previous_transcript_store)
      end
    end)

    :ok
  end

  test "run/1 delegates to the configured runtime dependencies" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, %Message.Outbound{content: content}} =
             Nexus.run(inbound)

    assert content =~ "Fake response:"
  end

  test "run/1 returns an error when runtime provider config is missing" do
    Application.delete_env(:nexus, :provider)

    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :missing_provider_config} =
             Nexus.run(inbound)
  end
end
