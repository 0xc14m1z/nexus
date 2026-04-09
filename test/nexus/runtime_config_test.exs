defmodule Nexus.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias Nexus.ProviderInstance
  alias Nexus.Providers.Fake
  alias Nexus.RuntimeConfig
  alias Nexus.SessionStoreInstance
  alias Nexus.SessionStores.InMemory, as: InMemorySessionStore
  alias Nexus.ToolInstance
  alias Nexus.Tools.CurrentTime
  alias Nexus.TranscriptStoreInstance
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  setup do
    previous_provider = Application.get_env(:nexus, :provider)
    previous_session_store = Application.get_env(:nexus, :session_store)
    previous_system_tools = Application.get_env(:nexus, :system_tools)
    previous_transcript_store = Application.get_env(:nexus, :transcript_store)
    previous_paths = Application.get_env(:nexus, :runtime_config_paths)

    on_exit(fn ->
      restore_env(:provider, previous_provider)
      restore_env(:session_store, previous_session_store)
      restore_env(:system_tools, previous_system_tools)
      restore_env(:transcript_store, previous_transcript_store)
      restore_env(:runtime_config_paths, previous_paths)
    end)

    :ok
  end

  test "runtime_dependencies/0 builds provider and store instances from app config" do
    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})
    Application.put_env(:nexus, :session_store, adapter: InMemorySessionStore, config: %{})
    Application.put_env(:nexus, :transcript_store, adapter: InMemoryTranscriptStore, config: %{})
    Application.put_env(:nexus, :system_tools, [[adapter: CurrentTime, config: %{}]])

    assert {:ok,
            %{
              provider: %ProviderInstance{adapter: Fake, config: %{}},
              session_store: %SessionStoreInstance{adapter: InMemorySessionStore, config: %{}},
              transcript_store: %TranscriptStoreInstance{
                adapter: InMemoryTranscriptStore,
                config: %{}
              },
              tools: [%ToolInstance{adapter: CurrentTime, source: :system}]
            }} = RuntimeConfig.runtime_dependencies()
  end

  test "runtime_dependencies_from_file/1 adds configured tools from one JSON file" do
    path = Path.join(System.tmp_dir!(), "nexus-runtime-dependencies-config-test.json")

    File.write!(path, """
    {
      "provider": {
        "adapter": "Nexus.Providers.Fake",
        "config": {}
      },
      "session_store": {
        "adapter": "Nexus.SessionStores.InMemory",
        "config": {}
      },
      "transcript_store": {
        "adapter": "Nexus.TranscriptStores.InMemory",
        "config": {}
      },
      "tools": [
        {
          "adapter": "Nexus.Tools.CurrentTime",
          "config": {}
        }
      ]
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok,
            %{
              provider: %ProviderInstance{adapter: Fake, config: %{}},
              session_store: %SessionStoreInstance{adapter: InMemorySessionStore, config: %{}},
              transcript_store: %TranscriptStoreInstance{
                adapter: InMemoryTranscriptStore,
                config: %{}
              },
              tools: [%ToolInstance{adapter: CurrentTime, source: :configured}]
            }} = RuntimeConfig.runtime_dependencies_from_file(path)
  end

  test "runtime_dependencies_from_file/1 keeps system tools separate from configured tools" do
    path = Path.join(System.tmp_dir!(), "nexus-runtime-dependencies-with-tools-config-test.json")

    Application.put_env(:nexus, :system_tools, [
      [adapter: CurrentTime, config: %{label: "system"}]
    ])

    File.write!(path, """
    {
      "provider": {
        "adapter": "Nexus.Providers.Fake",
        "config": {}
      },
      "session_store": {
        "adapter": "Nexus.SessionStores.InMemory",
        "config": {}
      },
      "transcript_store": {
        "adapter": "Nexus.TranscriptStores.InMemory",
        "config": {}
      },
      "tools": [
        {
          "adapter": "Nexus.Tools.CurrentTime",
          "config": {
            "label": "configured"
          }
        }
      ]
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok,
            %{
              tools: [
                %ToolInstance{adapter: CurrentTime, source: :system, config: %{label: "system"}},
                %ToolInstance{
                  adapter: CurrentTime,
                  source: :configured,
                  config: %{"label" => "configured"}
                }
              ]
            }} = RuntimeConfig.runtime_dependencies_from_file(path)
  end

  test "provider_instance/0 returns an error when provider config is missing" do
    Application.delete_env(:nexus, :provider)

    assert {:error, :missing_provider_config} = RuntimeConfig.provider_instance()
  end

  test "provider_instance/0 returns an error for malformed provider config" do
    Application.put_env(:nexus, :provider, adapter: Fake)

    assert {:error, {:invalid_provider_config, [adapter: Fake]}} =
             RuntimeConfig.provider_instance()
  end

  test "provider_instance_from_file/1 builds a provider instance from a JSON file" do
    path = Path.join(System.tmp_dir!(), "nexus-runtime-config-test.json")

    File.write!(path, """
    {
      "provider": {
        "adapter": "Nexus.Providers.Fake",
        "config": {}
      }
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, %ProviderInstance{adapter: Fake, config: %{}}} =
             RuntimeConfig.provider_instance_from_file(path)
  end

  test "session_store_instance_from_file/1 builds a session store instance from a JSON file" do
    path = Path.join(System.tmp_dir!(), "nexus-session-store-config-test.json")

    File.write!(path, """
    {
      "session_store": {
        "adapter": "Nexus.SessionStores.InMemory",
        "config": {}
      }
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, %SessionStoreInstance{adapter: InMemorySessionStore, config: %{}}} =
             RuntimeConfig.session_store_instance_from_file(path)
  end

  test "transcript_store_instance_from_file/1 builds a transcript store instance from a JSON file" do
    path = Path.join(System.tmp_dir!(), "nexus-transcript-store-config-test.json")

    File.write!(path, """
    {
      "transcript_store": {
        "adapter": "Nexus.TranscriptStores.InMemory",
        "config": {}
      }
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, %TranscriptStoreInstance{adapter: InMemoryTranscriptStore, config: %{}}} =
             RuntimeConfig.transcript_store_instance_from_file(path)
  end

  test "tool_instances/0 returns only system tools when no runtime file is present" do
    Application.put_env(:nexus, :system_tools, [[adapter: CurrentTime, config: %{}]])
    Application.put_env(:nexus, :runtime_config_paths, [])

    assert {:ok, [%ToolInstance{adapter: CurrentTime, source: :system}]} =
             RuntimeConfig.tool_instances()
  end

  test "tool_instances_from_file/1 returns configured tools from a JSON file" do
    path = Path.join(System.tmp_dir!(), "nexus-tools-config-test.json")

    File.write!(path, """
    {
      "tools": [
        {
          "adapter": "Nexus.Tools.CurrentTime",
          "config": {}
        }
      ]
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, [%ToolInstance{adapter: CurrentTime, source: :configured}]} =
             RuntimeConfig.tool_instances_from_file(path)
  end

  defp restore_env(key, nil), do: Application.delete_env(:nexus, key)
  defp restore_env(key, value), do: Application.put_env(:nexus, key, value)
end
