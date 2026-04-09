defmodule Nexus.Provider.Result do
  @moduledoc """
  Union type for provider outputs.

  Provider results model the immediate outcome of a single provider call before
  the runtime decides how to react. The first useful split is between:

  - final assistant text
  - a request to execute one or more tools
  """

  alias Nexus.Provider.Result.Text
  alias Nexus.Provider.Result.ToolRequest

  @type t :: Text.t() | ToolRequest.t()
end
