defmodule Nexus.AgentLoopTest do
  use ExUnit.Case

  alias Nexus.AgentLoop
  alias Nexus.Message.Inbound
  alias Nexus.Message.Outbound
  alias Nexus.Providers.Fake

  test "run/2 converts inbound content into an outbound message through the provider" do
    inbound = %Inbound{
      session_id: "session_123",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok,
            %Outbound{
              session_id: "session_123",
              channel: :cli,
              content: "Fake response: hello nexus",
              metadata: %{}
            }} = AgentLoop.run(inbound, Fake)
  end

  test "run/2 returns an invalid provider error for a module that is not a provider" do
    inbound = %Inbound{
      session_id: "session_123",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, {:invalid_provider, String}} = AgentLoop.run(inbound, String)
  end

  test "run/2 assigns a session id when the inbound message does not have one" do
    inbound = %Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, %Outbound{session_id: session_id}} = AgentLoop.run(inbound, Fake)
    assert String.starts_with?(session_id, "session_")
  end
end
