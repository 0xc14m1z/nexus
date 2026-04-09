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
        assert {:ok, outbound} = CLI.run_once(raw_input)
        assert is_binary(outbound.session_id)
      end)

    assert output ==
             "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus\n"
  end

  test "interactive CLI keeps the session alive across turns in the same VM" do
    output =
      capture_io("hello nexus\ncontinue\n/exit\n", fn ->
        assert :ok = CLI.run_interactive()
      end)

    assert output =~ "Nexus interactive chat"
    assert output =~ "Commands: /new, /exit"
    assert output =~ "session_id=session_"
    assert output =~ "hello nexus"
    assert output =~ "continue"
    assert output =~ "bye"
  end

  test "run_once/2 can use an explicit JSON config file with file-backed stores" do
    base_directory =
      Path.join(System.tmp_dir!(), "nexus-cli-config-test-#{System.unique_integer([:positive])}")

    sessions_directory = Path.join(base_directory, "sessions")
    transcripts_directory = Path.join(base_directory, "transcripts")
    config_path = Path.join(base_directory, "nexus.test.json")

    File.mkdir_p!(sessions_directory)
    File.mkdir_p!(transcripts_directory)

    File.write!(config_path, """
    {
      "provider": {
        "adapter": "Nexus.Providers.Fake",
        "config": {}
      },
      "session_store": {
        "adapter": "Nexus.SessionStores.File",
        "config": {
          "directory": "#{sessions_directory}"
        }
      },
      "transcript_store": {
        "adapter": "Nexus.TranscriptStores.File",
        "config": {
          "directory": "#{transcripts_directory}"
        }
      }
    }
    """)

    on_exit(fn -> File.rm_rf(base_directory) end)

    output =
      capture_io(fn ->
        assert {:ok, first_outbound} =
                 CLI.run_once(%{session_id: nil, user_input: "hello nexus"},
                   config_path: config_path
                 )

        assert {:ok, second_outbound} =
                 CLI.run_once(
                   %{session_id: first_outbound.session_id, user_input: "continue"},
                   config_path: config_path
                 )

        assert second_outbound.content =~ "hello nexus"
        assert second_outbound.content =~ "continue"
      end)

    assert output =~ "Fake response:"
  end
end
