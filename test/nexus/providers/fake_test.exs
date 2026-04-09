defmodule Nexus.Providers.FakeTest do
  use ExUnit.Case

  alias Nexus.Message
  alias Nexus.Provider
  alias Nexus.Providers.Fake

  test "generate/2 returns a deterministic response based on the messages" do
    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :system, content: "You are Nexus."},
        %Message.LLM{role: :user, content: "hello nexus"}
      ]
    }

    assert {:ok,
            %Provider.Result{
              content: "Fake response: System:\nYou are Nexus.\n\nUser:\nhello nexus"
            }} =
             Fake.generate(request, %{})
  end
end
