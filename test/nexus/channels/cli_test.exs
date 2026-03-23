defmodule Nexus.Channels.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Nexus.Channels.CLI
  alias Nexus.Message.Inbound
  alias Nexus.Message.Outbound

  test "normalize_inbound/1 builds an inbound message from valid CLI input" do
    raw = %{
      session_id: "session_123",
      content: "hello from the terminal",
      metadata: %{source: :test}
    }

    assert {:ok,
            %Inbound{
              session_id: "session_123",
              channel: :cli,
              content: "hello from the terminal",
              metadata: %{source: :test}
            }} = CLI.normalize_inbound(raw)
  end

  test "normalize_inbound/1 returns an error for invalid input" do
    assert {:error, :invalid_cli_input} = CLI.normalize_inbound(%{content: "missing session id"})
  end

  test "deliver/1 prints outbound content to stdout" do
    outbound = %Outbound{
      session_id: "session_123",
      channel: :cli,
      content: "reply from runtime",
      metadata: %{}
    }

    assert capture_io(fn ->
             assert :ok = CLI.deliver(outbound)
           end) == "reply from runtime\n"
  end
end
