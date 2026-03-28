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
              content: generated_content,
              metadata: %{}
            }} = AgentLoop.run(inbound, Fake)

    assert generated_content ==
             "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus"
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

  test "run/2 returns an error when the inbound message does not have a session id" do
    inbound = %Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :missing_session_id} = AgentLoop.run(inbound, Fake)
  end
end
