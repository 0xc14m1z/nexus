defmodule Nexus.TranscriptStore do
  @moduledoc """
  Behaviour for persisting and reading session transcript messages.

  The message store is responsible only for the conversation history tied to a
  session. It does not store transport-level inbound/outbound messages and it
  does not store runtime events.
  """

  alias Nexus.Message

  @doc """
  Appends a session message to the transcript and returns the persisted value.

  Implementations may assign `id` and `inserted_at` if they are missing.
  """
  @callback append(message :: Message.Transcript.t()) ::
              {:ok, Message.Transcript.t()} | {:error, term()}

  @doc """
  Lists all persisted session messages for a given session, ordered from oldest
  to newest.
  """
  @callback list_by_session(session_id :: String.t()) ::
              {:ok, [Message.Transcript.t()]} | {:error, term()}
end
