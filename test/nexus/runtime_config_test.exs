defmodule Nexus.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias Nexus.ProviderInstance
  alias Nexus.Providers.Fake
  alias Nexus.RuntimeConfig
  alias Nexus.SessionStoreInstance
  alias Nexus.SessionStores.InMemory, as: InMemorySessionStore
  alias Nexus.TranscriptStoreInstance
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  setup do
    previous_config = Application.get_env(:nexus, :provider)
    previous_session_store = Application.get_env(:nexus, :session_store)
    previous_transcript_store = Application.get_env(:nexus, :transcript_store)
    previous_paths = Application.get_env(:nexus, :runtime_config_paths)

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

      if previous_paths == nil do
        Application.delete_env(:nexus, :runtime_config_paths)
      else
        Application.put_env(:nexus, :runtime_config_paths, previous_paths)
      end
    end)

    :ok
  end

  test "runtime_dependencies/0 builds provider and store instances from app config" do
    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})
    Application.put_env(:nexus, :session_store, adapter: InMemorySessionStore, config: %{})
    Application.put_env(:nexus, :transcript_store, adapter: InMemoryTranscriptStore, config: %{})

    assert {:ok,
            %{
              provider: %ProviderInstance{adapter: Fake, config: %{}},
              session_store: %SessionStoreInstance{adapter: InMemorySessionStore, config: %{}},
              transcript_store: %TranscriptStoreInstance{
                adapter: InMemoryTranscriptStore,
                config: %{}
              }
            }} = RuntimeConfig.runtime_dependencies()
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

  test "provider_instance/0 reads the first configured JSON path before app config" do
    path = Path.join(System.tmp_dir!(), "nexus-runtime-config-auto-test.json")

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
      }
    }
    """)

    on_exit(fn -> File.rm(path) end)

    Application.put_env(:nexus, :provider, adapter: Nexus.Providers.Anthropic, config: %{})
    Application.put_env(:nexus, :runtime_config_paths, [path])

    assert {:ok,
            %{
              provider: %ProviderInstance{adapter: Fake, config: %{}},
              session_store: %SessionStoreInstance{adapter: InMemorySessionStore, config: %{}},
              transcript_store: %TranscriptStoreInstance{
                adapter: InMemoryTranscriptStore,
                config: %{}
              }
            }} = RuntimeConfig.runtime_dependencies()
  end
end
