defmodule Nexus.LLM.Message do
  @moduledoc """
  Minimal internal message format used to talk to LLM providers.
  """

  @type role :: :system | :user | :assistant
  @type t :: %__MODULE__{
          role: role(),
          content: String.t()
        }

  defstruct [:role, :content]
end
