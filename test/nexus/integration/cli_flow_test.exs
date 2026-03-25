defmodule Nexus.Integration.CLIFlowTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nexus.Channels.CLI
  alias Nexus.Orchestrator
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "a CLI payload can flow through normalization, provider generation, and delivery" do
    raw_input = %{
      session_id: nil,
      content: "hello nexus"
    }

    assert {:ok, inbound} = CLI.normalize_inbound(raw_input)
    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory)

    output =
      capture_io(fn ->
        assert :ok = CLI.deliver(outbound)
      end)

    assert output == "Fake response: hello nexus\n"
  end
end
