defmodule Nexus.RuntimeConfig do
  @moduledoc """
  Runtime configuration reader for Nexus.

  This module keeps external configuration lookup outside the orchestrator and
  outside provider or store adapters.

  Each configured runtime dependency uses the same small shape:

  - `adapter`: the adapter module
  - `config`: an opaque map passed through to that adapter

  This module should not know adapter-specific keys.
  """

  alias Nexus.ProviderInstance
  alias Nexus.SessionStoreInstance
  alias Nexus.TranscriptStoreInstance

  @default_json_paths [
    "config/nexus.local.json",
    "config/nexus.json"
  ]

  @type runtime_dependencies :: %{
          provider: ProviderInstance.t(),
          session_store: SessionStoreInstance.t(),
          transcript_store: TranscriptStoreInstance.t()
        }

  @doc """
  Resolves the runtime dependencies needed to execute one Nexus turn.

  Resolution order:

  1. `config/nexus.local.json`
  2. `config/nexus.json`
  3. application config fallback
  """
  @spec runtime_dependencies() :: {:ok, runtime_dependencies()} | {:error, term()}
  def runtime_dependencies do
    with {:ok, source} <- load_runtime_source(),
         {:ok, provider} <- build_provider_instance(source),
         {:ok, session_store} <- build_session_store_instance(source),
         {:ok, transcript_store} <- build_transcript_store_instance(source) do
      {:ok,
       %{
         provider: provider,
         session_store: session_store,
         transcript_store: transcript_store
       }}
    end
  end

  @doc """
  Resolves the runtime dependencies declared in one explicit JSON config file.
  """
  @spec runtime_dependencies_from_file(Path.t()) ::
          {:ok, runtime_dependencies()} | {:error, term()}
  def runtime_dependencies_from_file(path) when is_binary(path) do
    with {:ok, {:file, decoded}} <- load_runtime_source_from_file(path),
         {:ok, provider} <- build_provider_instance({:file, decoded}),
         {:ok, session_store} <- build_session_store_instance({:file, decoded}),
         {:ok, transcript_store} <- build_transcript_store_instance({:file, decoded}) do
      {:ok,
       %{
         provider: provider,
         session_store: session_store,
         transcript_store: transcript_store
       }}
    end
  end

  @doc """
  Builds the configured provider instance declared in runtime configuration.
  """
  @spec provider_instance() :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance do
    with {:ok, source} <- load_runtime_source() do
      build_provider_instance(source)
    end
  end

  @doc """
  Builds the configured session store instance declared in runtime configuration.
  """
  @spec session_store_instance() :: {:ok, SessionStoreInstance.t()} | {:error, term()}
  def session_store_instance do
    with {:ok, source} <- load_runtime_source() do
      build_session_store_instance(source)
    end
  end

  @doc """
  Builds the configured transcript store instance declared in runtime configuration.
  """
  @spec transcript_store_instance() :: {:ok, TranscriptStoreInstance.t()} | {:error, term()}
  def transcript_store_instance do
    with {:ok, source} <- load_runtime_source() do
      build_transcript_store_instance(source)
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
    with {:ok, {:file, decoded}} <- load_runtime_source_from_file(path) do
      build_provider_instance({:file, decoded})
    end
  end

  @doc """
  Builds a session store instance from a JSON config file.
  """
  @spec session_store_instance_from_file(Path.t()) ::
          {:ok, SessionStoreInstance.t()} | {:error, term()}
  def session_store_instance_from_file(path) when is_binary(path) do
    with {:ok, {:file, decoded}} <- load_runtime_source_from_file(path) do
      build_session_store_instance({:file, decoded})
    end
  end

  @doc """
  Builds a transcript store instance from a JSON config file.
  """
  @spec transcript_store_instance_from_file(Path.t()) ::
          {:ok, TranscriptStoreInstance.t()} | {:error, term()}
  def transcript_store_instance_from_file(path) when is_binary(path) do
    with {:ok, {:file, decoded}} <- load_runtime_source_from_file(path) do
      build_transcript_store_instance({:file, decoded})
    end
  end

  # JSON config wins when present; otherwise we fall back to application config.
  defp load_runtime_source do
    case existing_json_config_path() do
      nil -> {:ok, :app_config}
      path -> load_runtime_source_from_file(path)
    end
  end

  # A JSON file is treated as a runtime source, not as a provider-only config,
  # because provider and stores can all be overridden from the same document.
  defp load_runtime_source_from_file(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, decoded} <- Jason.decode(contents) do
      {:ok, {:file, decoded}}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:invalid_runtime_config_json, path, Exception.message(error)}}

      {:error, reason} ->
        {:error, reason}
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

  # Each top-level key maps to one runtime dependency, e.g. `provider` or
  # `session_store`. Missing file keys fall back to the matching app config.
  defp build_provider_instance(source) do
    with {:ok, adapter, config} <-
           normalize_runtime_section(source, "provider", :provider, :provider) do
      ProviderInstance.new(adapter, config)
    end
  end

  # Session store resolution follows the same adapter/config shape as the
  # provider so the high-level runtime can stay uniform.
  defp build_session_store_instance(source) do
    with {:ok, adapter, config} <-
           normalize_runtime_section(source, "session_store", :session_store, :session_store) do
      SessionStoreInstance.new(adapter, config)
    end
  end

  # Transcript store resolution is kept symmetrical with the other runtime
  # dependencies so JSON and app config stay predictable.
  defp build_transcript_store_instance(source) do
    with {:ok, adapter, config} <-
           normalize_runtime_section(
             source,
             "transcript_store",
             :transcript_store,
             :transcript_store
           ) do
      TranscriptStoreInstance.new(adapter, config)
    end
  end

  # Runtime sections can come either from JSON or from standard application
  # config, but they normalize down to the same `{adapter, config}` tuple.
  defp normalize_runtime_section({:file, decoded}, json_key, app_key, error_tag) do
    case Map.get(decoded, json_key) do
      nil -> normalize_runtime_section(:app_config, json_key, app_key, error_tag)
      section when is_map(section) -> normalize_file_section(section, error_tag)
      other -> {:error, {invalid_config_tag(error_tag), other}}
    end
  end

  defp normalize_runtime_section(:app_config, _json_key, app_key, error_tag) do
    normalize_app_section(Application.get_env(:nexus, app_key), error_tag)
  end

  # The JSON file stores module names as strings, so we normalize the adapter
  # reference before building the corresponding runtime instance.
  defp normalize_file_section(%{"adapter" => adapter_name, "config" => config}, error_tag)
       when is_binary(adapter_name) and is_map(config) do
    case resolve_module(adapter_name) do
      {:ok, adapter} -> {:ok, adapter, config}
      {:error, _reason} -> {:error, {invalid_adapter_tag(error_tag), adapter_name}}
    end
  end

  defp normalize_file_section(other, error_tag) do
    {:error, {invalid_config_tag(error_tag), other}}
  end

  # Application config keeps the same adapter/config shape used before JSON was
  # introduced, so existing defaults continue to work unchanged.
  defp normalize_app_section(nil, :provider), do: {:error, :missing_provider_config}
  defp normalize_app_section(nil, :session_store), do: {:error, :missing_session_store_config}

  defp normalize_app_section(nil, :transcript_store),
    do: {:error, :missing_transcript_store_config}

  defp normalize_app_section([adapter: adapter, config: config], _error_tag)
       when is_atom(adapter) and is_map(config) do
    {:ok, adapter, config}
  end

  defp normalize_app_section(%{adapter: adapter, config: config}, _error_tag)
       when is_atom(adapter) and is_map(config) do
    {:ok, adapter, config}
  end

  # Malformed app config keeps the failing section visible in the error tag, so
  # configuration mistakes remain easy to diagnose from the CLI.
  defp normalize_app_section(other, error_tag) do
    {:error, {invalid_config_tag(error_tag), other}}
  end

  # These helpers keep the section-specific error atoms in one place instead of
  # duplicating them across the normalization logic above.
  defp invalid_config_tag(:provider), do: :invalid_provider_config
  defp invalid_config_tag(:session_store), do: :invalid_session_store_config
  defp invalid_config_tag(:transcript_store), do: :invalid_transcript_store_config

  defp invalid_adapter_tag(:provider), do: :invalid_provider_adapter
  defp invalid_adapter_tag(:session_store), do: :invalid_session_store_adapter
  defp invalid_adapter_tag(:transcript_store), do: :invalid_transcript_store_adapter

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
      {:error, {:module_not_loaded, module_name}}
    end
  end
end
