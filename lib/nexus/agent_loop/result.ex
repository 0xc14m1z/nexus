defmodule Nexus.AgentLoop.Result do
  @moduledoc """
  Result of a single agent turn.

  It separates the final assistant content produced by the turn from the
  transcript messages meant to be persisted.
  """

  alias Nexus.Message

  @type t :: %__MODULE__{
          assistant_content: String.t(),
          transcript_messages: [Message.Transcript.t()]
        }

  defstruct [:assistant_content, transcript_messages: []]
end
