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

  @default_json_paths [
    "config/nexus.local.json",
    "config/nexus.json"
  ]

  @doc """
  Builds the configured provider instance declared in runtime configuration.

  Resolution order:

  1. `config/nexus.local.json`
  2. `config/nexus.json`
  3. application config fallback
  """
  @spec provider_instance() :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance do
    case existing_json_config_path() do
      nil -> provider_instance_from_app_config()
      path -> provider_instance_from_file(path)
    end
  end

  @doc """
  Builds a provider instance from a JSON config file.

  Expected shape:

      {
        "provider": {
          "adapter": "Nexus.Providers.Anthropic",
          "config": { ... }
        }
      }
  """
  @spec provider_instance_from_file(Path.t()) :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance_from_file(path) when is_binary(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, decoded} <- Jason.decode(contents),
         {:ok, provider_config} <- fetch_provider_config(decoded),
         {:ok, adapter, config} <- normalize_provider_config(provider_config) do
      ProviderInstance.new(adapter, config)
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:invalid_runtime_config_json, path, Exception.message(error)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Application config remains the final fallback so the runtime still boots
  # even when no JSON config file is present.
  defp provider_instance_from_app_config do
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

  # Local config wins over shared config so personal secrets and overrides stay
  # out of versioned project files.
  defp existing_json_config_path do
    json_config_paths()
    |> Enum.find(&File.exists?/1)
  end

  # Tests can override these lookup paths to keep local secret files from
  # changing the expected runtime behavior.
  defp json_config_paths do
    Application.get_env(:nexus, :runtime_config_paths, @default_json_paths)
  end

  # The top-level JSON document stays intentionally small: for now it only
  # needs a single `provider` object.
  defp fetch_provider_config(%{"provider" => provider_config}) when is_map(provider_config) do
    {:ok, provider_config}
  end

  defp fetch_provider_config(other) do
    {:error, {:invalid_provider_config_file, other}}
  end

  # The JSON file stores module names as strings, so we normalize the adapter
  # reference before building the provider instance.
  defp normalize_provider_config(%{"adapter" => adapter_name, "config" => config})
       when is_binary(adapter_name) and is_map(config) do
    case resolve_module(adapter_name) do
      {:ok, adapter} -> {:ok, adapter, config}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_provider_config(other) do
    {:error, {:invalid_provider_config, other}}
  end

  # We resolve the module name eagerly so configuration errors fail before the
  # runtime starts executing a turn.
  defp resolve_module(module_name) do
    module =
      module_name
      |> String.split(".")
      |> Module.concat()

    if Code.ensure_loaded?(module) do
      {:ok, module}
    else
      {:error, {:invalid_provider_adapter, module_name}}
    end
  end
end
