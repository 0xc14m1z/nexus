defmodule Nexus.SessionStore do
  @moduledoc """
  Behaviour for loading and saving sessions.

  This is the first persistence-oriented contract in the project.
  A concrete adapter will later decide where sessions live: memory, Postgres,
  or something else.
  """

  alias Nexus.Session

  @doc """
  Loads a session by id.
  """
  @callback get(session_id :: Session.id()) :: {:ok, Session.t()} | :not_found

  @doc """
  Saves a session and returns the persisted value.

  A concrete store may decide to assign the session id during this step.
  """
  @callback save(session :: Session.t()) :: {:ok, Session.t()} | {:error, term()}
end
