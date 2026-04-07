defmodule Nexus.SessionStoreInstance do
  @moduledoc """
  Runtime wrapper around a session store adapter and its resolved configuration.

  This keeps storage configuration outside the orchestrator while still letting
  the runtime work with a ready-to-use session store value.
  """

  alias Nexus.AdapterValidator
  alias Nexus.Session

  @type t :: %__MODULE__{
          adapter: module(),
          config: Nexus.SessionStore.config()
        }

  defstruct [:adapter, config: %{}]

  @doc """
  Builds a session store instance from an adapter module and a config map.
  """
  @spec new(module(), Nexus.SessionStore.config()) :: {:ok, t()} | {:error, term()}
  def new(adapter, config) when is_map(config) do
    with :ok <- AdapterValidator.validate_session_store(adapter) do
      {:ok, %__MODULE__{adapter: adapter, config: config}}
    end
  end

  def new(adapter, _config) do
    {:error, {:invalid_session_store_reference, adapter}}
  end

  @doc """
  Loads a session from the configured store instance.
  """
  @spec get(t(), Session.id()) :: {:ok, Session.t()} | :not_found | {:error, term()}
  def get(%__MODULE__{adapter: adapter, config: config}, session_id) do
    with :ok <- AdapterValidator.validate_session_store(adapter) do
      adapter.get(session_id, config)
    end
  end

  @doc """
  Saves a session through the configured store instance.
  """
  @spec save(t(), Session.t()) :: {:ok, Session.t()} | {:error, term()}
  def save(%__MODULE__{adapter: adapter, config: config}, %Session{} = session) do
    with :ok <- AdapterValidator.validate_session_store(adapter) do
      adapter.save(session, config)
    end
  end
end
