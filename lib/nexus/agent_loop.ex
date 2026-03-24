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

  alias Nexus.Message.Inbound
  alias Nexus.Message.Outbound
  alias Nexus.Session

  @doc """
  Executes one minimal agent turn.

  The provider module must implement `Nexus.Provider`.
  """
  @spec run(Inbound.t(), module()) :: {:ok, Outbound.t()} | {:error, term()}
  def run(%Inbound{} = inbound, provider) do
    with :ok <- validate_provider(provider) do
      prompt = to_string(inbound.content)
      session_id = Session.ensure_id(inbound.session_id)

      case provider.generate(prompt) do
        {:ok, generated_text} ->
          {:ok,
           %Outbound{
             session_id: session_id,
             channel: inbound.channel,
             content: generated_text,
             metadata: %{}
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_provider(provider) when is_atom(provider) do
    cond do
      not Code.ensure_loaded?(provider) ->
        {:error, {:invalid_provider, provider}}

      not function_exported?(provider, :generate, 1) ->
        {:error, {:invalid_provider, provider}}

      true ->
        :ok
    end
  end

  defp validate_provider(provider) do
    {:error, {:invalid_provider, provider}}
  end
end
