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

  alias Nexus.AdapterValidator
  alias Nexus.ContextBuilder
  alias Nexus.AgentLoop.Result
  alias Nexus.Message

  @doc """
  Executes one minimal agent turn.

  The provider module must implement `Nexus.Provider`.
  The session id must already be resolved by the orchestrator.
  """
  @spec run(String.t(), [Message.Transcript.t()], module()) ::
          {:ok, Result.t()} | {:error, term()}
  def run(session_id, transcript_messages, provider) do
    with :ok <- AdapterValidator.validate_provider(provider),
         {:ok, session_id} <- validate_session_id(session_id),
         {:ok, messages} <- ContextBuilder.build_messages(transcript_messages),
         {:ok, generated_text} <- provider.generate(messages) do
      {:ok,
       %Result{
         assistant_content: generated_text,
         transcript_messages: [
           %Message.Transcript.Assistant{
             session_id: session_id,
             content: generated_text
           }
         ]
       }}
    end
  end

  # The orchestrator is responsible for resolving or creating the session
  # before delegating the turn to the agent loop.
  defp validate_session_id(session_id) when is_binary(session_id), do: {:ok, session_id}
  defp validate_session_id(_session_id), do: {:error, :missing_session_id}
end
