defmodule Nexus.ProviderInstance do
  @moduledoc """
  Runtime wrapper around a provider adapter and its resolved configuration.

  The goal is to keep provider bootstrapping outside the agent loop:

  - the orchestrator or another setup layer resolves the adapter and config
  - the agent loop receives a provider that is already ready to use
  """

  alias Nexus.AdapterValidator
  alias Nexus.Message

  @type t :: %__MODULE__{
          adapter: module(),
          config: Nexus.Provider.config()
        }

  defstruct [:adapter, config: %{}]

  @doc """
  Builds a provider instance from an adapter module and a config map.
  """
  @spec new(module(), Nexus.Provider.config()) :: {:ok, t()} | {:error, term()}
  def new(adapter, config) when is_map(config) do
    with :ok <- AdapterValidator.validate_provider(adapter) do
      {:ok, %__MODULE__{adapter: adapter, config: config}}
    end
  end

  def new(adapter, _config) do
    {:error, {:invalid_provider_reference, adapter}}
  end

  @doc """
  Calls the provider instance with a list of LLM messages.
  """
  @spec generate(t(), [Message.LLM.t()]) :: {:ok, String.t()} | {:error, term()}
  def generate(%__MODULE__{adapter: adapter, config: config}, messages) do
    with :ok <- AdapterValidator.validate_provider(adapter) do
      adapter.generate(messages, config)
    end
  end
end
