defmodule Nexus.SessionTest do
  use ExUnit.Case

  alias Nexus.Session

  test "ensure_id/1 returns the existing session id when one is already present" do
    assert Session.ensure_id("session_123") == "session_123"
  end

  test "ensure_id/1 creates a session id when the input is nil" do
    session_id = Session.ensure_id(nil)

    assert is_binary(session_id)
    assert String.starts_with?(session_id, "session_")
  end
end
