defmodule Nexus.AgentLoopTest do
  use ExUnit.Case

  alias Nexus.AgentLoop
  alias Nexus.AgentLoop.Result
  alias Nexus.Message
  alias Nexus.Provider
  alias Nexus.ProviderInstance
  alias Nexus.Providers.Fake

  defmodule ToolRequestProvider do
    @behaviour Nexus.Provider

    alias Nexus.Provider

    @impl true
    def generate(%Provider.Request{}, _config) do
      {:ok,
       %Provider.Result.ToolRequest{
         tool_calls: [
           %{id: "call_123", name: "current_time", arguments: %{}}
         ]
       }}
    end
  end

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
              llm_messages: [
                %Message.LLM{role: :system},
                %Message.LLM{role: :user, content: "hello nexus"}
              ],
              transcript_messages: [
                %Message.Transcript.Assistant{content: generated_content}
              ]
            }} =
             AgentLoop.run(
               "session_123",
               transcript_messages,
               %ProviderInstance{adapter: Fake, config: %{}}
             )

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
             AgentLoop.run(
               "session_123",
               transcript_messages,
               %ProviderInstance{adapter: String, config: %{}}
             )
  end

  test "run/3 returns an error when the session id is missing" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    assert {:error, :missing_session_id} =
             AgentLoop.run(
               nil,
               transcript_messages,
               %ProviderInstance{adapter: Fake, config: %{}}
             )
  end

  test "run/3 returns an error for an invalid provider reference" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "hello nexus"
      }
    ]

    assert {:error, {:invalid_provider_reference, Fake}} =
             AgentLoop.run("session_123", transcript_messages, Fake)
  end

  test "run/3 returns an explicit error when the provider requests tools" do
    transcript_messages = [
      %Message.Transcript.User{
        session_id: "session_123",
        content: "what time is it?"
      }
    ]

    assert {:error,
            {:tool_requests_not_supported,
             [%{id: "call_123", name: "current_time", arguments: %{}}]}} =
             AgentLoop.run(
               "session_123",
               transcript_messages,
               %ProviderInstance{adapter: ToolRequestProvider, config: %{}}
             )
  end
end
