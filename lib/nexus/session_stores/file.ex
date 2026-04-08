defmodule Nexus.SessionStores.File do
  @moduledoc """
  File-backed `SessionStore` adapter.

  Each session is stored as a single JSON file inside the configured directory.
  This keeps the first persistent store implementation easy to inspect and easy
  to reason about while the runtime is still evolving.
  """

  @behaviour Nexus.SessionStore

  alias Nexus.Session

  @default_directory "var/nexus/sessions"

  @impl true
  def get(session_id, config) when is_binary(session_id) and is_map(config) do
    path = session_path(session_id, config)

    with :ok <- ensure_directory(config),
         {:ok, contents} <- read_session_file(path),
         {:ok, decoded} <- Jason.decode(contents),
         {:ok, session} <- decode_session(decoded) do
      {:ok, session}
    end
  end

  @impl true
  def save(%Session{} = session, config) when is_map(config) do
    with :ok <- ensure_directory(config) do
      now = DateTime.utc_now()

      persisted_session =
        session
        |> ensure_id()
        |> ensure_created_at(now)
        |> Map.put(:updated_at, now)

      persisted_session
      |> encode_session()
      |> Jason.encode!(pretty: true)
      |> then(&File.write(session_path(persisted_session.id, config), &1))
      |> case do
        :ok -> {:ok, persisted_session}
        {:error, reason} -> {:error, {:session_store_write_failed, reason}}
      end
    end
  end

  @doc """
  Clears all persisted session files in the configured directory.

  This helper is mainly useful in tests and local manual resets.
  """
  @spec clear(map()) :: :ok | {:error, term()}
  def clear(config \\ %{}) do
    with :ok <- ensure_directory(config),
         {:ok, entries} <- File.ls(directory(config)) do
      Enum.reduce_while(entries, :ok, fn entry, :ok ->
        case File.rm(Path.join(directory(config), entry)) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {:session_store_clear_failed, reason}}}
        end
      end)
    end
  end

  # Existing sessions keep their assigned id, while brand new sessions get a
  # simple monotonic identifier from the file-backed adapter.
  defp ensure_id(%Session{id: id} = session) when is_binary(id), do: session

  defp ensure_id(%Session{} = session) do
    %{
      session
      | id: "session_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
    }
  end

  # `created_at` is assigned only once so repeated saves behave like updates.
  defp ensure_created_at(%Session{created_at: nil} = session, now) do
    %{session | created_at: now}
  end

  defp ensure_created_at(%Session{} = session, _now), do: session

  # File-backed stores rely on an explicit directory so the location stays
  # configurable from the outside instead of being hidden in the adapter.
  defp ensure_directory(config) do
    case File.mkdir_p(directory(config)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:session_store_directory_error, reason}}
    end
  end

  # Missing files map to `:not_found` so callers get the same semantics as the
  # in-memory store adapter.
  defp read_session_file(path) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, :enoent} -> :not_found
      {:error, reason} -> {:error, {:session_store_read_failed, reason}}
    end
  end

  # Sessions are encoded as plain JSON-compatible maps so the files stay easy
  # to inspect and do not depend on Elixir-specific serialization.
  defp encode_session(%Session{} = session) do
    %{
      "id" => session.id,
      "created_at" => encode_datetime(session.created_at),
      "updated_at" => encode_datetime(session.updated_at)
    }
  end

  # Decoding validates the expected shape up front so malformed files fail fast
  # instead of leaking partial state into the runtime.
  defp decode_session(%{
         "id" => id,
         "created_at" => created_at,
         "updated_at" => updated_at
       })
       when is_binary(id) do
    with {:ok, created_at} <- decode_datetime(created_at),
         {:ok, updated_at} <- decode_datetime(updated_at) do
      {:ok, %Session{id: id, created_at: created_at, updated_at: updated_at}}
    end
  end

  defp decode_session(other) do
    {:error, {:invalid_session_store_payload, other}}
  end

  # Timestamps are stored as ISO8601 strings to keep the on-disk format human
  # readable while preserving precise ordering information.
  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp decode_datetime(nil), do: {:ok, nil}

  defp decode_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, reason} -> {:error, {:invalid_session_store_datetime, reason}}
    end
  end

  defp decode_datetime(other), do: {:error, {:invalid_session_store_datetime, other}}

  defp session_path(session_id, config) do
    Path.join(directory(config), "#{session_id}.json")
  end

  # JSON config may use string keys, while tests often use atom keys, so the
  # adapter accepts both representations transparently.
  defp directory(config) do
    Map.get(config, :directory, Map.get(config, "directory", @default_directory))
  end
end
