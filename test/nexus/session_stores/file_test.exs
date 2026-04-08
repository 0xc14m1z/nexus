defmodule Nexus.SessionStores.FileTest do
  use ExUnit.Case, async: false

  alias Nexus.Session
  alias Nexus.SessionStores.File, as: FileStore

  setup do
    directory =
      Path.join(System.tmp_dir!(), "nexus-session-store-#{System.unique_integer([:positive])}")

    config = %{directory: directory}

    on_exit(fn -> File.rm_rf(directory) end)

    {:ok, config: config}
  end

  test "save/2 assigns id and timestamps when they are missing", %{config: config} do
    assert {:ok, %Session{} = session} = FileStore.save(%Session{}, config)

    assert is_binary(session.id)
    assert String.starts_with?(session.id, "session_")
    assert %DateTime{} = session.created_at
    assert %DateTime{} = session.updated_at
    assert File.exists?(Path.join(config.directory, "#{session.id}.json"))
  end

  test "get/2 returns a previously saved session", %{config: config} do
    input = %Session{id: "session_123"}

    assert {:ok, %Session{} = saved_session} = FileStore.save(input, config)
    assert {:ok, loaded_session} = FileStore.get("session_123", config)

    assert loaded_session == saved_session
  end

  test "get/2 returns :not_found when the session file does not exist", %{config: config} do
    assert :not_found = FileStore.get("session_missing", config)
  end
end
