defmodule Nexus.Integration.CLIFlowTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nexus.CLI
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    InMemoryTranscriptStore.clear()

    previous_config = Application.get_env(:nexus, :provider)
    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:nexus, :provider)
      else
        Application.put_env(:nexus, :provider, previous_config)
      end
    end)

    :ok
  end

  test "a CLI payload can flow through Nexus.CLI and delivery" do
    raw_input = %{
      session_id: nil,
      user_input: "hello nexus"
    }

    output =
      capture_io(fn ->
        assert {:ok, outbound} = CLI.run_once(raw_input, InMemory, InMemoryTranscriptStore)
        assert is_binary(outbound.session_id)
      end)

    assert output ==
             "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus\n"
  end

  test "interactive CLI keeps the session alive across turns in the same VM" do
    output =
      capture_io("hello nexus\ncontinue\n/exit\n", fn ->
        assert :ok = CLI.run_interactive(InMemory, InMemoryTranscriptStore)
      end)

    assert output =~ "Nexus interactive chat"
    assert output =~ "Commands: /new, /exit"
    assert output =~ "session_id=session_"
    assert output =~ "hello nexus"
    assert output =~ "continue"
    assert output =~ "bye"
  end
end
