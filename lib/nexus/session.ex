defmodule Nexus.Session do
  @moduledoc """
  Minimal session data structure.

  At this stage the session is intentionally small. It gives us a concrete shape
  for the data that a future `SessionStore` will save and load.
  """

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id() | nil,
          created_at: DateTime.t() | nil
        }

  defstruct [:id, :created_at]
end
