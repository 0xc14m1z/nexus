defmodule Nexus.ContextBuilderTest do
  use ExUnit.Case

  alias Nexus.ContextBuilder
  alias Nexus.Message

  test "build_messages/1 combines the system prompt with inbound content" do
    inbound = %Message.Inbound{
      session_id: "session_123",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    expected_messages = [
      %Message.LLM{
        role: :system,
        content:
          "You are Nexus.\nHelp the user understand and build the agent framework step by step."
      },
      %Message.LLM{role: :user, content: "hello nexus"}
    ]

    assert {:ok, ^expected_messages} = ContextBuilder.build_messages(inbound)
  end

  test "build_messages/1 returns an error for unsupported content" do
    inbound = %Message.Inbound{
      session_id: "session_123",
      channel: :cli,
      content: %{text: "hello nexus"},
      metadata: %{}
    }

    assert {:error, :unsupported_inbound_content} = ContextBuilder.build_messages(inbound)
  end
end
