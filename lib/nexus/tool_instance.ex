defmodule Nexus.ToolInstance do
  @moduledoc """
  Runtime wrapper around a tool adapter and its resolved configuration.

  The wrapper also keeps track of where the tool came from:

  - `:system` for tools bundled or enabled by the harness itself
  - `:configured` for tools explicitly added through external runtime config
  """

  alias Nexus.AdapterValidator

  @type source :: :system | :configured

  @type t :: %__MODULE__{
          adapter: module(),
          config: Nexus.Tool.config(),
          source: source()
        }

  defstruct [:adapter, config: %{}, source: :configured]

  @doc """
  Builds a tool instance from an adapter module and a config map.
  """
  @spec new(module(), Nexus.Tool.config(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(adapter, config, opts \\ [])

  def new(adapter, config, opts) when is_map(config) and is_list(opts) do
    source = Keyword.get(opts, :source, :configured)

    with :ok <- validate_source(source),
         :ok <- AdapterValidator.validate_tool(adapter) do
      {:ok, %__MODULE__{adapter: adapter, config: config, source: source}}
    end
  end

  def new(adapter, _config, _opts) do
    {:error, {:invalid_tool_reference, adapter}}
  end

  @doc """
  Returns the provider-facing definition for this tool instance.
  """
  @spec definition(t()) :: Nexus.Tool.definition()
  def definition(%__MODULE__{adapter: adapter, config: config}) do
    adapter.definition(config)
  end

  @doc """
  Executes the tool with parsed arguments.
  """
  @spec call(t(), map()) :: {:ok, String.t()} | {:error, term()}
  def call(%__MODULE__{adapter: adapter, config: config}, arguments) when is_map(arguments) do
    with :ok <- AdapterValidator.validate_tool(adapter) do
      adapter.call(arguments, config)
    end
  end

  defp validate_source(source) when source in [:system, :configured], do: :ok
  defp validate_source(source), do: {:error, {:invalid_tool_source, source}}
end
