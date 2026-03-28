defmodule Nexus.SessionMessage do
  @moduledoc """
  Minimal persisted message shape for a session transcript.

  A session message is not a transport-level inbound/outbound message and it is
  not a provider-facing LLM message. It is the conversation item we want to keep
  in session history so later turns can reconstruct context.
  """

  @type role :: :user | :assistant

  @type t :: %__MODULE__{
          id: String.t() | nil,
          session_id: String.t(),
          role: role(),
          content: String.t(),
          inserted_at: DateTime.t() | nil
        }

  defstruct [:id, :session_id, :role, :content, :inserted_at]
end
