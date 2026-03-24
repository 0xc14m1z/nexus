defmodule Nexus.Session do
  @moduledoc """
  Minimal session data structure.

  At this stage the session is intentionally small. It gives us a concrete shape
  for the data that a future `SessionStore` will save and load.

  The helper functions for session ids remain here temporarily so the current
  flow can keep working until we introduce a concrete session store adapter.
  """

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id() | nil,
          created_at: DateTime.t() | nil
        }

  defstruct [:id, :created_at]

  @doc """
  Returns a new minimal session struct.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Generates a new session identifier.

  This function is temporary and will move out of this module when a concrete
  session store takes responsibility for session creation.
  """
  @spec new_id() :: id()
  def new_id do
    "session_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  @doc """
  Returns the existing session id or creates a new one when the input is `nil`.

  This function is temporary and will disappear once session creation is handled
  through a store-backed flow.
  """
  @spec ensure_id(id() | nil) :: id()
  def ensure_id(nil), do: new_id()
  def ensure_id(session_id) when is_binary(session_id), do: session_id
end
