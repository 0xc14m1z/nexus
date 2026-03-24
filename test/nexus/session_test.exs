defmodule Nexus.SessionTest do
  use ExUnit.Case

  alias Nexus.Session

  test "session is a minimal data structure with id and timestamps" do
    assert %Session{id: nil, created_at: nil, updated_at: nil} = %Session{}
  end
end
