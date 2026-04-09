defmodule Nexus.Provider.Result.Text do
  @moduledoc """
  Final assistant text returned by a provider call.
  """

  @type t :: %__MODULE__{
          content: String.t()
        }

  defstruct [:content]
end
