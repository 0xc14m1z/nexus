defmodule Nexus.AgentLoop do
  @moduledoc """
  Minimal synchronous agent loop.

  This first version is intentionally small and executes a single turn:

  - receives an inbound message
  - treats the inbound content as the provider prompt
  - calls the chosen provider
  - wraps the generated text into an outbound message

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
  The inbound message must already belong to a session.
  """
  @spec run(Message.Inbound.t(), module()) :: {:ok, Result.t()} | {:error, term()}
  def run(%Message.Inbound{} = inbound, provider) do
    with :ok <- AdapterValidator.validate_provider(provider),
         {:ok, session_id} <- validate_session_id(inbound.session_id),
         {:ok, messages} <- ContextBuilder.build_messages(inbound),
         {:ok, generated_text} <- provider.generate(messages) do
      outbound = %Message.Outbound{
        session_id: session_id,
        channel: inbound.channel,
        content: generated_text,
        metadata: %{}
      }

      {:ok,
       %Result{
         outbound: outbound,
         transcript_messages: [
           %Message.Transcript.Assistant{
             session_id: session_id,
             content: generated_text
           }
         ]
       }}
    end
  end

  defp validate_session_id(session_id) when is_binary(session_id), do: {:ok, session_id}
  defp validate_session_id(_session_id), do: {:error, :missing_session_id}
end
