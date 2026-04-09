defmodule Nexus.Provider.Request do
  @moduledoc """
  Structured request passed from the agent loop to a provider adapter.

  For now it contains only the provider-facing LLM messages for the current
  call. The shape is already explicit so the provider contract can evolve
  without passing around loose positional arguments.
  """

  alias Nexus.Message

  @type t :: %__MODULE__{
          messages: [Message.LLM.t()]
        }

  defstruct messages: []
end
