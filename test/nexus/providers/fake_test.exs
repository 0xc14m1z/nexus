defmodule Nexus.Providers.FakeTest do
  use ExUnit.Case

  alias Nexus.Providers.Fake

  test "generate/1 returns a deterministic response based on the prompt" do
    assert {:ok, "Fake response: hello nexus"} = Fake.generate("hello nexus")
  end
end
