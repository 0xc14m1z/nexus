defmodule Nexus.Provider.Result do
  @moduledoc """
  Structured output returned by a provider adapter.

  The first version still models only final assistant text, but returning a
  struct now gives us a clear place to grow when providers start requesting
  tools or exposing richer response metadata.
  """

  @type t :: %__MODULE__{
          content: String.t()
        }

  defstruct [:content]
end
