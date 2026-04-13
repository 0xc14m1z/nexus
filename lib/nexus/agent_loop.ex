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
  alias Nexus.ToolInstance

  @doc """
  Executes one minimal agent turn.

  The provider must already be configured by the orchestrator.
  The session id must already be resolved by the orchestrator.
  """
  @spec run(String.t(), [Message.Transcript.t()], ProviderInstance.t(), [ToolInstance.t()]) ::
          {:ok, Result.t()} | {:error, term()}
  def run(session_id, transcript_messages, %ProviderInstance{} = provider, tool_instances) do
    with {:ok, session_id} <- validate_session_id(session_id),
         {:ok, messages} <- ContextBuilder.build_messages(transcript_messages),
         {:ok, tools} <- build_request_tools(tool_instances),
         {:ok, provider_result} <-
           ProviderInstance.generate(provider, %Provider.Request{messages: messages, tools: tools}) do
      build_loop_result(session_id, messages, provider_result)
    end
  end

  def run(_session_id, _transcript_messages, provider, _tool_instances) do
    {:error, {:invalid_provider_reference, provider}}
  end

  # The orchestrator is responsible for resolving or creating the session
  # before delegating the turn to the agent loop.
  defp validate_session_id(session_id) when is_binary(session_id), do: {:ok, session_id}
  defp validate_session_id(_session_id), do: {:error, :missing_session_id}

  # Provider requests carry generic tool definitions, not runtime tool
  # instances, so the loop flattens configured tools into provider-facing data
  # before calling the adapter.
  defp build_request_tools(tool_instances) when is_list(tool_instances) do
    Enum.reduce_while(tool_instances, {:ok, []}, fn
      %ToolInstance{} = tool_instance, {:ok, acc} ->
        {:cont, {:ok, [ToolInstance.definition(tool_instance) | acc]}}

      _other, {:ok, _acc} ->
        {:halt, {:error, :invalid_tool_instances}}
    end)
    |> case do
      {:ok, tools} -> {:ok, Enum.reverse(tools)}
      error -> error
    end
  end

  defp build_request_tools(_tool_instances) do
    {:error, :invalid_tool_instances}
  end

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
