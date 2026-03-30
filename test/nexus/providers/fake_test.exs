defmodule Nexus.Providers.FakeTest do
  use ExUnit.Case

  alias Nexus.Message
  alias Nexus.Providers.Fake

  test "generate/1 returns a deterministic response based on the messages" do
    messages = [
      %Message.LLM{role: :system, content: "You are Nexus."},
      %Message.LLM{role: :user, content: "hello nexus"}
    ]

    assert {:ok, "Fake response: System:\nYou are Nexus.\n\nUser:\nhello nexus"} =
             Fake.generate(messages)
  end
end
