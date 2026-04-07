defmodule Nexus.TranscriptStoreInstance do
  @moduledoc """
  Runtime wrapper around a transcript store adapter and its resolved configuration.

  This mirrors `ProviderInstance` and `SessionStoreInstance` so the
  orchestrator can work with transcript storage without knowing where the
  adapter gets its configuration from.
  """

  alias Nexus.AdapterValidator
  alias Nexus.Message

  @type t :: %__MODULE__{
          adapter: module(),
          config: Nexus.TranscriptStore.config()
        }

  defstruct [:adapter, config: %{}]

  @doc """
  Builds a transcript store instance from an adapter module and a config map.
  """
  @spec new(module(), Nexus.TranscriptStore.config()) :: {:ok, t()} | {:error, term()}
  def new(adapter, config) when is_map(config) do
    with :ok <- AdapterValidator.validate_transcript_store(adapter) do
      {:ok, %__MODULE__{adapter: adapter, config: config}}
    end
  end

  def new(adapter, _config) do
    {:error, {:invalid_transcript_store_reference, adapter}}
  end

  @doc """
  Appends a transcript message through the configured store instance.
  """
  @spec append(t(), Message.Transcript.t()) ::
          {:ok, Message.Transcript.t()} | {:error, term()}
  def append(%__MODULE__{adapter: adapter, config: config}, message) do
    with :ok <- AdapterValidator.validate_transcript_store(adapter) do
      adapter.append(message, config)
    end
  end

  @doc """
  Lists transcript messages for a session through the configured store instance.
  """
  @spec list_by_session(t(), String.t()) :: {:ok, [Message.Transcript.t()]} | {:error, term()}
  def list_by_session(%__MODULE__{adapter: adapter, config: config}, session_id) do
    with :ok <- AdapterValidator.validate_transcript_store(adapter) do
      adapter.list_by_session(session_id, config)
    end
  end
end
