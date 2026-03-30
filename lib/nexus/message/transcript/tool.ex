defmodule Nexus.Message.Transcript.Tool do
  @moduledoc """
  Persisted tool result message in a session transcript.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          session_id: String.t(),
          tool_call_id: String.t(),
          name: String.t(),
          content: String.t(),
          inserted_at: DateTime.t() | nil
        }

  defstruct [:id, :session_id, :tool_call_id, :name, :content, :inserted_at]
end
