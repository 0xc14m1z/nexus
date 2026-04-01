defmodule Nexus.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias Nexus.ProviderInstance
  alias Nexus.Providers.Fake
  alias Nexus.RuntimeConfig

  setup do
    previous_config = Application.get_env(:nexus, :provider)

    on_exit(fn ->
      if previous_config == nil do
        Application.delete_env(:nexus, :provider)
      else
        Application.put_env(:nexus, :provider, previous_config)
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
end
