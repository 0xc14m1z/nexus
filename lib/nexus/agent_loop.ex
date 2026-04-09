defmodule Nexus.AgentLoop do
  @moduledoc """
  Minimal synchronous agent loop.

  This first version is intentionally small and executes a single turn:

  - receives a session id
  - receives the current session transcript
  - asks the context builder to turn that transcript into provider messages
  - calls the chosen provider
  - returns the generated assistant content and transcript result

  It is not yet a GenServer and it does not manage tools, history, or retries.
  Those responsibilities will arrive later as the real runtime grows.
  """

  alias Nexus.ProviderInstance
  alias Nexus.ContextBuilder
  alias Nexus.AgentLoop.Result
  alias Nexus.Message
  alias Nexus.Provider

  @doc """
  Executes one minimal agent turn.

  The provider must already be configured by the orchestrator.
  The session id must already be resolved by the orchestrator.
  """
  @spec run(String.t(), [Message.Transcript.t()], ProviderInstance.t()) ::
          {:ok, Result.t()} | {:error, term()}
  def run(session_id, transcript_messages, %ProviderInstance{} = provider) do
    with {:ok, session_id} <- validate_session_id(session_id),
         {:ok, messages} <- ContextBuilder.build_messages(transcript_messages),
         {:ok, provider_result} <-
           ProviderInstance.generate(provider, %Provider.Request{messages: messages}) do
      build_loop_result(session_id, messages, provider_result)
    end
  end

  def run(_session_id, _transcript_messages, provider) do
    {:error, {:invalid_provider_reference, provider}}
  end

  # The orchestrator is responsible for resolving or creating the session
  # before delegating the turn to the agent loop.
  defp validate_session_id(session_id) when is_binary(session_id), do: {:ok, session_id}
  defp validate_session_id(_session_id), do: {:error, :missing_session_id}

  # Text results are still the only branch the loop knows how to turn into a
  # final assistant reply. Tool requests are modeled already, but execution
  # support will arrive in the next slice.
  defp build_loop_result(session_id, messages, %Provider.Result.Text{content: generated_text}) do
    {:ok,
     %Result{
       assistant_content: generated_text,
       llm_messages: messages,
       transcript_messages: [
         %Message.Transcript.Assistant{
           session_id: session_id,
           content: generated_text
         }
       ]
     }}
  end

  defp build_loop_result(_session_id, _messages, %Provider.Result.ToolRequest{
         tool_calls: tool_calls
       }) do
    {:error, {:tool_requests_not_supported, tool_calls}}
  end
end
