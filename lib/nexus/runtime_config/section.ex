defmodule Nexus.RuntimeConfig.Section do
  @moduledoc """
  Normalization helpers for runtime config sections.

  This module converts JSON-loaded or app-config-loaded sections into the same
  small `{adapter, config}` tuples used by runtime instances.
  """

  alias Nexus.RuntimeConfig.Source

  @type error_tag :: :provider | :session_store | :transcript_store | :tool
  @type normalized_section :: {:ok, module(), map()} | {:error, term()}

  @doc """
  Normalizes one top-level runtime dependency section.
  """
  @spec normalize_runtime_section(Source.t(), String.t(), atom(), error_tag()) ::
          normalized_section()
  def normalize_runtime_section({:file, decoded}, json_key, app_key, error_tag) do
    case Map.get(decoded, json_key) do
      nil -> normalize_runtime_section(:app_config, json_key, app_key, error_tag)
      section when is_map(section) -> normalize_file_section(section, error_tag)
      other -> {:error, {invalid_config_tag(error_tag), other}}
    end
  end

  def normalize_runtime_section(:app_config, _json_key, app_key, error_tag) do
    normalize_app_section(Application.get_env(:nexus, app_key), error_tag)
  end

  @doc """
  Normalizes a list of tool sections coming either from app config or JSON.
  """
  @spec normalize_tool_sections(term()) :: {:ok, [{module(), map()}]} | {:error, term()}
  def normalize_tool_sections(sections) when is_list(sections) do
    Enum.reduce_while(sections, {:ok, []}, fn section, {:ok, acc} ->
      case normalize_tool_section(section) do
        {:ok, adapter, config} -> {:cont, {:ok, [{adapter, config} | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  def normalize_tool_sections(other) do
    {:error, {:invalid_tool_config, other}}
  end

  # Tool sections can come from either app config or JSON, so we accept both
  # shapes explicitly instead of forcing the caller to branch first.
  defp normalize_tool_section(section) when is_list(section) or is_map(section) do
    case normalize_app_section(section, :tool) do
      {:ok, adapter, config} ->
        {:ok, adapter, config}

      {:error, _reason} ->
        case normalize_file_section(section, :tool) do
          {:ok, adapter, config} -> {:ok, adapter, config}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp normalize_tool_section(other) do
    {:error, {:invalid_tool_config, other}}
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

  defp normalize_app_section(other, error_tag) do
    {:error, {invalid_config_tag(error_tag), other}}
  end

  # These helpers keep the section-specific error atoms in one place instead of
  # duplicating them across the normalization logic above.
  defp invalid_config_tag(:provider), do: :invalid_provider_config
  defp invalid_config_tag(:session_store), do: :invalid_session_store_config
  defp invalid_config_tag(:transcript_store), do: :invalid_transcript_store_config
  defp invalid_config_tag(:tool), do: :invalid_tool_config

  defp invalid_adapter_tag(:provider), do: :invalid_provider_adapter
  defp invalid_adapter_tag(:session_store), do: :invalid_session_store_adapter
  defp invalid_adapter_tag(:transcript_store), do: :invalid_transcript_store_adapter
  defp invalid_adapter_tag(:tool), do: :invalid_tool_adapter

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
