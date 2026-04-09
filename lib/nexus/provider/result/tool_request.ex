defmodule Nexus.Provider.Result.ToolRequest do
  @moduledoc """
  Provider result requesting one or more tool executions.
  """

  @type tool_call :: %{
          id: String.t(),
          name: String.t(),
          arguments: map()
        }

  @type t :: %__MODULE__{
          tool_calls: [tool_call()]
        }

  defstruct tool_calls: []
end
