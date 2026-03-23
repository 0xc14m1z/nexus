defmodule Nexus.Message.Outbound do
  @moduledoc """
  Minimal outbound message shape emitted by the runtime.

  This first version intentionally mirrors the inbound message:

  - `session_id` should be known when the runtime produces a reply
  - `channel` identifies which adapter should deliver the message
  - `content` stays generic until we know how we want to model it
  - `metadata` holds adapter-specific extras
  """

  @type t :: %__MODULE__{
          session_id: String.t(),
          channel: atom(),
          content: term(),
          metadata: map()
        }

  defstruct [:session_id, :channel, :content, metadata: %{}]
end
