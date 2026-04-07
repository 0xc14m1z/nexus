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
  @spec run(Message.Inbound.t()) :: {:ok, Message.Outbound.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound) do
    with {:ok,
          %{provider: provider, session_store: session_store, transcript_store: transcript_store}} <-
           RuntimeConfig.runtime_dependencies() do
      Orchestrator.run(inbound, provider, session_store, transcript_store)
    end
  end
end
