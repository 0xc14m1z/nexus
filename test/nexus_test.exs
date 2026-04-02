defmodule NexusTest do
  use ExUnit.Case

  alias Nexus
  alias Nexus.Message
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  setup do
    previous_config = Application.get_env(:nexus, :provider)

    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})
    InMemory.clear()
    InMemoryTranscriptStore.clear()

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:nexus, :provider)
      else
        Application.put_env(:nexus, :provider, previous_config)
      end
    end)

    :ok
  end

  test "run/3 delegates to the configured runtime provider" do
    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, %Message.Outbound{content: content}} =
             Nexus.run(inbound, InMemory, InMemoryTranscriptStore)

    assert content =~ "Fake response:"
  end

  test "run/3 returns an error when runtime provider config is missing" do
    Application.delete_env(:nexus, :provider)

    inbound = %Message.Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :missing_provider_config} =
             Nexus.run(inbound, InMemory, InMemoryTranscriptStore)
  end
end
