defmodule Nexus.RuntimeConfig.Source do
  @moduledoc """
  Source-loading helpers for runtime configuration.

  This module owns only the mechanics of:

  - choosing which JSON file to read
  - loading file contents
  - decoding JSON into one runtime source value
  """

  @default_json_paths [
    "config/nexus.local.json",
    "config/nexus.json"
  ]

  @type t :: :app_config | {:file, map()}

  @doc """
  Loads the active runtime source.

  Resolution order:

  1. `config/nexus.local.json`
  2. `config/nexus.json`
  3. application config fallback
  """
  @spec load_runtime_source() :: {:ok, t()} | {:error, term()}
  def load_runtime_source do
    case existing_json_config_path() do
      nil -> {:ok, :app_config}
      path -> load_runtime_source_from_file(path)
    end
  end

  @doc """
  Loads one explicit runtime JSON file and decodes it as a runtime source.
  """
  @spec load_runtime_source_from_file(Path.t()) :: {:ok, t()} | {:error, term()}
  def load_runtime_source_from_file(path) when is_binary(path) do
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
end
