defmodule Nexus.ContextBuilder do
  @moduledoc """
  Minimal prompt builder for the agent loop.

  In this first version the context builder only knows how to turn inbound
  message content into the prompt string sent to the provider.
  """

  alias Nexus.Message.Inbound

  @doc """
  Builds the provider prompt for a single inbound message.
  """
  @spec build_prompt(Inbound.t()) :: {:ok, String.t()} | {:error, term()}
  def build_prompt(%Inbound{content: content}) when is_binary(content) do
    {:ok, content}
  end

  def build_prompt(%Inbound{}) do
    {:error, :unsupported_inbound_content}
  end
end
