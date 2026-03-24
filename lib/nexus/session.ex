defmodule Nexus.Session do
  @moduledoc """
  Minimal session helper functions.

  This module exists to make one idea explicit very early in the project:
  a message may already belong to a session, or it may need a new session id.

  For now this module does not store sessions and does not model session state.
  It only helps us work with session identifiers in a clear way.
  """

  @type id :: String.t()

  @doc """
  Generates a new session identifier.
  """
  @spec new_id() :: id()
  def new_id do
    "session_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  @doc """
  Returns the existing session id or creates a new one when the input is `nil`.
  """
  @spec ensure_id(id() | nil) :: id()
  def ensure_id(nil), do: new_id()
  def ensure_id(session_id) when is_binary(session_id), do: session_id
end
