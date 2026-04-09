defmodule Nexus.Tool do
  @moduledoc """
  Minimal contract for an executable tool adapter.

  A tool exposes:

  - a provider-facing definition that describes how the model can call it
  - an execution callback that runs the tool with already-parsed arguments
  """

  @type config :: map()
  @type definition :: %{
          name: String.t(),
          description: String.t(),
          input_schema: map()
        }

  @doc """
  Returns the definition for one tool as seen by the model.
  """
  @callback definition(config :: config()) :: definition()

  @doc """
  Executes the tool with parsed arguments and resolved config.
  """
  @callback call(arguments :: map(), config :: config()) ::
              {:ok, String.t()} | {:error, term()}
end
