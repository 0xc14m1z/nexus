defmodule Nexus.Message.Transcript.User do
  @moduledoc """
  Persisted user message in a session transcript.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          session_id: String.t(),
          content: String.t(),
          inserted_at: DateTime.t() | nil
        }

  defstruct [:id, :session_id, :content, :inserted_at]
end
