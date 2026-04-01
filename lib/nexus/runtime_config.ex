defmodule Nexus.RuntimeConfig do
  @moduledoc """
  Minimal runtime configuration reader for Nexus.

  This module keeps external configuration lookup outside the orchestrator and
  outside provider adapters.

  The provider configuration shape is intentionally generic:

  - `adapter`: the provider module
  - `config`: an opaque map passed through to that adapter

  This module should not know provider-specific keys.
  """

  alias Nexus.ProviderInstance

  @doc """
  Builds the configured provider instance declared in application config.
  """
  @spec provider_instance() :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance do
    case Application.get_env(:nexus, :provider) do
      nil ->
        {:error, :missing_provider_config}

      [adapter: adapter, config: config] when is_atom(adapter) and is_map(config) ->
        ProviderInstance.new(adapter, config)

      %{adapter: adapter, config: config} when is_atom(adapter) and is_map(config) ->
        ProviderInstance.new(adapter, config)

      other ->
        {:error, {:invalid_provider_config, other}}
    end
  end
end
