defmodule Nexus.ContextBuilderTest do
  use ExUnit.Case

  alias Nexus.ContextBuilder
  alias Nexus.Message

  test "build_messages/1 combines the system prompt with transcript history" do
    transcript_messages = [
      %Message.Transcript.Assistant{
        session_id: "session_123",
        content: "previous answer"
      },
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    expected_messages = [
      %Message.LLM{
        role: :system,
        content:
          "You are Nexus.\nHelp the user understand and build the agent framework step by step."
      },
      %Message.LLM{role: :assistant, content: "previous answer"},
      %Message.LLM{role: :user, content: "hello nexus"}
    ]

    assert {:ok, ^expected_messages} = ContextBuilder.build_messages(transcript_messages)
  end

  test "build_messages/1 returns an error for unsupported transcript messages" do
    transcript_messages = [
      %Message.Transcript.Tool{
        session_id: "session_123",
        tool_call_id: "call_123",
        name: "search",
        content: "tool result"
      }
    ]

    assert {:error, :unsupported_transcript_message} =
             ContextBuilder.build_messages(transcript_messages)
  end

  test "build_messages/1 returns an error for invalid input" do
    inbound = %Message.Inbound{
      session_id: "session_123",
      channel: :cli,
      content: %{text: "hello nexus"},
      metadata: %{}
    }

    assert {:error, :invalid_transcript_messages} = ContextBuilder.build_messages(inbound)
  end
end
