defmodule Nexus.Integration.CLIFlowTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nexus.Channels.CLI
  alias Nexus.ProviderInstance
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore
  alias Nexus.Orchestrator
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    InMemoryTranscriptStore.clear()

    {:ok, provider} = ProviderInstance.new(Fake, %{})

    {:ok, provider: provider}
  end

  test "a CLI payload can flow through normalization, provider generation, and delivery", %{
    provider: provider
  } do
    raw_input = %{
      session_id: nil,
      content: "hello nexus"
    }

    assert {:ok, inbound} = CLI.normalize_inbound(raw_input)

    assert {:ok, outbound} =
             Orchestrator.run(inbound, provider, InMemory, InMemoryTranscriptStore)

    output =
      capture_io(fn ->
        assert :ok = CLI.deliver(outbound)
      end)

    assert output ==
             "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus\n"
  end
end
