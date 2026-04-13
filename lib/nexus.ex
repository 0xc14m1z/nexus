defmodule Nexus do
  @moduledoc """
  High-level runtime entrypoint for Nexus.
  """

  alias Nexus.Message
  alias Nexus.Orchestrator
  alias Nexus.RuntimeConfig

  @doc """
  Runs one turn using the runtime dependencies declared in configuration.
  """
  def run(inbound, opts \\ [])

  @spec run(Message.Inbound.t(), keyword()) :: {:ok, Message.Outbound.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound, opts) when is_list(opts) do
    with {:ok,
          %{
            provider: provider,
            session_store: session_store,
            transcript_store: transcript_store,
            tools: tools
          }} <-
           resolve_runtime_dependencies(opts) do
      Orchestrator.run(inbound, provider, session_store, transcript_store, tools)
    end
  end

  # A manual config path is useful for smoke tests and local experiments,
  # but the public runtime entrypoint still stays as one `run/2`.
  defp resolve_runtime_dependencies(opts) do
    case Keyword.get(opts, :config_path) do
      nil ->
        RuntimeConfig.runtime_dependencies()

      path when is_binary(path) ->
        RuntimeConfig.runtime_dependencies_from_file(path)
    end
  end
end
