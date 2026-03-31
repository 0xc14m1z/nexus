defmodule Nexus.AgentLoopTest do
  use ExUnit.Case

  alias Nexus.AgentLoop
  alias Nexus.AgentLoop.Result
  alias Nexus.Message
  alias Nexus.Providers.Fake

  test "run/3 converts transcript history into assistant content through the provider" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    assert {:ok,
            %Result{
              assistant_content: generated_content,
              transcript_messages: [
                %Message.Transcript.Assistant{content: generated_content}
              ]
            }} = AgentLoop.run("session_123", transcript_messages, Fake)

    assert generated_content ==
             "Fake response: System:\nYou are Nexus.\nHelp the user understand and build the agent framework step by step.\n\nUser:\nhello nexus"
  end

  test "run/3 returns an invalid provider error for a module that is not a provider" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    assert {:error, {:invalid_provider, String}} =
             AgentLoop.run("session_123", transcript_messages, String)
  end

  test "run/3 returns an error when the session id is missing" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    assert {:error, :missing_session_id} = AgentLoop.run(nil, transcript_messages, Fake)
  end
end
