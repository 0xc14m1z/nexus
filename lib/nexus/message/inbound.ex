defmodule Nexus.Message.Inbound do
  @moduledoc """
  Minimal inbound message shape used by the runtime.

  This first version is intentionally small:

  - `session_id` may be `nil` when a new session has to be created
  - `channel` identifies which adapter produced the message
  - `content` is kept generic for now so we can evolve it step by step
  - `metadata` holds adapter-specific extras
  """

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          channel: atom(),
          content: term(),
          metadata: map()
        }

  defstruct [:session_id, :channel, :content, metadata: %{}]
end
