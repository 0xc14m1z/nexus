defmodule Nexus.Channels.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Nexus.Channels.CLI
  alias Nexus.Message

  test "normalize_inbound/1 builds an inbound message from valid CLI input" do
    raw = %{
      session_id: "session_123",
      user_input: "hello from the terminal",
      metadata: %{source: :test}
    }

    assert {:ok,
            %Message.Inbound{
              session_id: "session_123",
              channel: :cli,
              content: "hello from the terminal",
              metadata: %{source: :test}
            }} = CLI.normalize_inbound(raw)
  end

  test "normalize_inbound/1 returns an error for invalid input" do
    assert {:error, :invalid_cli_input} =
             CLI.normalize_inbound(%{user_input: "missing session id"})
  end

  test "deliver/1 prints outbound content to stdout" do
    outbound = %Message.Outbound{
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
