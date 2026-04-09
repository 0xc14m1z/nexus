defmodule Nexus.RuntimeConfig do
  @moduledoc """
  Runtime configuration facade for Nexus.

  This module keeps the public runtime-config API small while delegating the
  actual work to more focused helpers:

  - `Nexus.RuntimeConfig.Source` chooses and loads the config source
  - `Nexus.RuntimeConfig.Section` normalizes provider/store sections
  - `Nexus.RuntimeConfig.Tools` builds tool instances from system and runtime config
  """

  alias Nexus.ProviderInstance
  alias Nexus.RuntimeConfig.Section
  alias Nexus.RuntimeConfig.Source
  alias Nexus.RuntimeConfig.Tools
  alias Nexus.SessionStoreInstance
  alias Nexus.ToolInstance
  alias Nexus.TranscriptStoreInstance

  @type runtime_dependencies :: %{
          provider: ProviderInstance.t(),
          session_store: SessionStoreInstance.t(),
          transcript_store: TranscriptStoreInstance.t(),
          tools: [ToolInstance.t()]
        }

  @doc """
  Resolves the runtime dependencies needed to execute one Nexus turn.
  """
  @spec runtime_dependencies() :: {:ok, runtime_dependencies()} | {:error, term()}
  def runtime_dependencies do
    with {:ok, source} <- Source.load_runtime_source(),
         {:ok, provider} <- build_provider_instance(source),
         {:ok, session_store} <- build_session_store_instance(source),
         {:ok, transcript_store} <- build_transcript_store_instance(source),
         {:ok, tools} <- Tools.build_tool_instances(source) do
      {:ok,
       %{
         provider: provider,
         session_store: session_store,
         transcript_store: transcript_store,
         tools: tools
       }}
    end
  end

  @doc """
  Resolves the runtime dependencies declared in one explicit JSON config file.
  """
  @spec runtime_dependencies_from_file(Path.t()) ::
          {:ok, runtime_dependencies()} | {:error, term()}
  def runtime_dependencies_from_file(path) when is_binary(path) do
    with {:ok, source} <- Source.load_runtime_source_from_file(path),
         {:ok, provider} <- build_provider_instance(source),
         {:ok, session_store} <- build_session_store_instance(source),
         {:ok, transcript_store} <- build_transcript_store_instance(source),
         {:ok, tools} <- Tools.build_tool_instances(source) do
      {:ok,
       %{
         provider: provider,
         session_store: session_store,
         transcript_store: transcript_store,
         tools: tools
       }}
    end
  end

  @doc """
  Builds the configured provider instance declared in runtime configuration.
  """
  @spec provider_instance() :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance do
    with {:ok, source} <- Source.load_runtime_source() do
      build_provider_instance(source)
    end
  end

  @doc """
  Builds the configured session store instance declared in runtime configuration.
  """
  @spec session_store_instance() :: {:ok, SessionStoreInstance.t()} | {:error, term()}
  def session_store_instance do
    with {:ok, source} <- Source.load_runtime_source() do
      build_session_store_instance(source)
    end
  end

  @doc """
  Builds the configured transcript store instance declared in runtime configuration.
  """
  @spec transcript_store_instance() :: {:ok, TranscriptStoreInstance.t()} | {:error, term()}
  def transcript_store_instance do
    with {:ok, source} <- Source.load_runtime_source() do
      build_transcript_store_instance(source)
    end
  end

  @doc """
  Builds the configured tool instances declared in runtime configuration.
  """
  @spec tool_instances() :: {:ok, [ToolInstance.t()]} | {:error, term()}
  def tool_instances do
    with {:ok, source} <- Source.load_runtime_source() do
      Tools.build_tool_instances(source)
    end
  end

  @doc """
  Builds a provider instance from a JSON config file.
  """
  @spec provider_instance_from_file(Path.t()) :: {:ok, ProviderInstance.t()} | {:error, term()}
  def provider_instance_from_file(path) when is_binary(path) do
    with {:ok, source} <- Source.load_runtime_source_from_file(path) do
      build_provider_instance(source)
    end
  end

  @doc """
  Builds a session store instance from a JSON config file.
  """
  @spec session_store_instance_from_file(Path.t()) ::
          {:ok, SessionStoreInstance.t()} | {:error, term()}
  def session_store_instance_from_file(path) when is_binary(path) do
    with {:ok, source} <- Source.load_runtime_source_from_file(path) do
      build_session_store_instance(source)
    end
  end

  @doc """
  Builds a transcript store instance from a JSON config file.
  """
  @spec transcript_store_instance_from_file(Path.t()) ::
          {:ok, TranscriptStoreInstance.t()} | {:error, term()}
  def transcript_store_instance_from_file(path) when is_binary(path) do
    with {:ok, source} <- Source.load_runtime_source_from_file(path) do
      build_transcript_store_instance(source)
    end
  end

  @doc """
  Builds tool instances from a JSON config file.
  """
  @spec tool_instances_from_file(Path.t()) :: {:ok, [ToolInstance.t()]} | {:error, term()}
  def tool_instances_from_file(path) when is_binary(path) do
    with {:ok, source} <- Source.load_runtime_source_from_file(path) do
      Tools.build_tool_instances(source)
    end
  end

  # Each top-level key maps to one runtime dependency, e.g. `provider` or
  # `session_store`. Missing file keys fall back to the matching app config.
  defp build_provider_instance(source) do
    with {:ok, adapter, config} <-
           Section.normalize_runtime_section(source, "provider", :provider, :provider) do
      ProviderInstance.new(adapter, config)
    end
  end

  # Session store resolution follows the same adapter/config shape as the
  # provider so the high-level runtime can stay uniform.
  defp build_session_store_instance(source) do
    with {:ok, adapter, config} <-
           Section.normalize_runtime_section(
             source,
             "session_store",
             :session_store,
             :session_store
           ) do
      SessionStoreInstance.new(adapter, config)
    end
  end

  # Transcript store resolution is kept symmetrical with the other runtime
  # dependencies so JSON and app config stay predictable.
  defp build_transcript_store_instance(source) do
    with {:ok, adapter, config} <-
           Section.normalize_runtime_section(
             source,
             "transcript_store",
             :transcript_store,
             :transcript_store
           ) do
      TranscriptStoreInstance.new(adapter, config)
    end
  end
end
