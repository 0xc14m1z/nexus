defmodule Nexus.Tools.CurrentTimeTest do
  use ExUnit.Case

  alias Nexus.Tools.CurrentTime

  test "call/2 returns an ISO8601 UTC timestamp" do
    assert {:ok, timestamp} = CurrentTime.call(%{}, %{})
    assert {:ok, %DateTime{time_zone: "Etc/UTC"}, 0} = DateTime.from_iso8601(timestamp)
  end

  test "call/2 rejects unexpected arguments" do
    assert {:error, :current_time_takes_no_arguments} =
             CurrentTime.call(%{"timezone" => "Europe/Zurich"}, %{})
  end
end
