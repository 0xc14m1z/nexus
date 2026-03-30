defmodule Nexus.AgentLoop.Result do
  @moduledoc """
  Result of a single agent turn.

  It separates the external reply to send back out from the transcript messages
  produced by the turn and meant to be persisted.
  """

  alias Nexus.Message

  @type t :: %__MODULE__{
          outbound: Message.Outbound.t(),
          transcript_messages: [Message.Transcript.t()]
        }

  defstruct [:outbound, transcript_messages: []]
end
