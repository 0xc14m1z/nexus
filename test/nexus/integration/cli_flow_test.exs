defmodule Nexus.Integration.CLIFlowTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Nexus.AgentLoop
  alias Nexus.Channels.CLI
  alias Nexus.Providers.Fake

  test "a CLI payload can flow through normalization, provider generation, and delivery" do
    raw_input = %{
      session_id: "session_123",
      content: "hello nexus"
    }

    assert {:ok, inbound} = CLI.normalize_inbound(raw_input)
    assert {:ok, outbound} = AgentLoop.run(inbound, Fake)

    output =
      capture_io(fn ->
        assert :ok = CLI.deliver(outbound)
      end)

    assert output == "Fake response: hello nexus\n"
  end
end
