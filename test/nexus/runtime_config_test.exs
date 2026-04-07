defmodule Nexus.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias Nexus.ProviderInstance
  alias Nexus.Providers.Fake
  alias Nexus.RuntimeConfig

  setup do
    previous_config = Application.get_env(:nexus, :provider)
    previous_paths = Application.get_env(:nexus, :runtime_config_paths)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:nexus, :provider)
      else
        Application.put_env(:nexus, :provider, previous_config)
      end

      if previous_paths == nil do
        Application.delete_env(:nexus, :runtime_config_paths)
      else
        Application.put_env(:nexus, :runtime_config_paths, previous_paths)
      end
    end)

    :ok
  end

  test "provider_instance/0 builds a provider instance from app config" do
    Application.put_env(:nexus, :provider, adapter: Fake, config: %{})

    assert {:ok, %ProviderInstance{adapter: Fake, config: %{}}} =
             RuntimeConfig.provider_instance()
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

  test "provider_instance/0 reads the first configured JSON path before app config" do
    path = Path.join(System.tmp_dir!(), "nexus-runtime-config-auto-test.json")

    File.write!(path, """
    {
      "provider": {
        "adapter": "Nexus.Providers.Fake",
        "config": {}
      }
    }
    """)

    on_exit(fn -> File.rm(path) end)

    Application.put_env(:nexus, :provider, adapter: Nexus.Providers.Anthropic, config: %{})
    Application.put_env(:nexus, :runtime_config_paths, [path])

    assert {:ok, %ProviderInstance{adapter: Fake, config: %{}}} =
             RuntimeConfig.provider_instance()
  end
end
