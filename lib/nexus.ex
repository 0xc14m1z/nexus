defmodule Nexus do
  @moduledoc """
  High-level runtime entrypoint for Nexus.
  """

  alias Nexus.Message
  alias Nexus.Orchestrator
  alias Nexus.RuntimeConfig

  @doc """
  Runs one turn using the provider declared in runtime configuration.
  """
  @spec run(Message.Inbound.t(), module(), module()) ::
          {:ok, Message.Outbound.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound, session_store, transcript_store) do
    with {:ok, provider} <- RuntimeConfig.provider_instance() do
      Orchestrator.run(inbound, provider, session_store, transcript_store)
    end
  end
end
