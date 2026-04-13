defmodule Nexus.Provider.Request do
  @moduledoc """
  Structured request passed from the agent loop to a provider adapter.

  It contains:

  - the provider-facing LLM messages for the current call
  - the tool definitions available to the model for this call

  The shape is already explicit so the provider contract can evolve without
  passing around loose positional arguments.
  """

  alias Nexus.Message
  alias Nexus.Tool

  @type t :: %__MODULE__{
          messages: [Message.LLM.t()],
          tools: [Tool.definition()]
        }

  defstruct messages: [], tools: []
end
