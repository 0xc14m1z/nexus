defmodule Nexus.SessionStore do
  @moduledoc """
  Behaviour for loading and saving sessions.

  This is the first persistence-oriented contract in the project.
  A concrete adapter will later decide where sessions live: memory, Postgres,
  or something else.

  The external semantics are intentionally small and stable:

  - `get/1` loads a session by id
  - `save/1` persists a session using upsert-like semantics
  - if the session has no id yet, the store may assign it during `save/1`
  - `save/1` always returns the persisted session value
  """

  alias Nexus.Session

  @doc """
  Loads a session by id.
  """
  @callback get(session_id :: Session.id()) :: {:ok, Session.t()} | :not_found

  @doc """
  Saves a session and returns the persisted value.

  This operation has upsert-like semantics.
  A concrete store may decide to assign the session id during this step when it
  is still missing.
  """
  @callback save(session :: Session.t()) :: {:ok, Session.t()} | {:error, term()}
end
