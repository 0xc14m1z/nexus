defmodule Nexus.Message.Transcript.AssistantToolCall do
  @moduledoc """
  Persisted assistant tool-call message in a session transcript.
  """

  @type tool_call :: map()

  @type t :: %__MODULE__{
          id: String.t() | nil,
          session_id: String.t(),
          tool_calls: [tool_call()],
          inserted_at: DateTime.t() | nil
        }

  defstruct [:id, :session_id, :tool_calls, :inserted_at]
end
