defmodule Nexus.SessionTest do
  use ExUnit.Case

  alias Nexus.Session

  test "session is a minimal data structure with id and created_at" do
    assert %Session{id: nil, created_at: nil} = %Session{}
  end
end
