defmodule Nexus.Runner do
  @moduledoc """
  Temporary minimal flow runner used to exercise the first end-to-end path.

  This module is intentionally small and may disappear later when orchestration and
  the real agent loop are introduced.

  For now it does only this:

  - receives an inbound message
  - treats the inbound content as the provider prompt
  - calls the chosen provider
  - wraps the generated text into an outbound message
  """

  alias Nexus.Message.Inbound
  alias Nexus.Message.Outbound
  alias Nexus.Session

  @doc """
  Runs the smallest possible message flow.

  The provider module must implement `Nexus.Provider`.
  """
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
