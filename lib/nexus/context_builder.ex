defmodule Nexus.ContextBuilder do
  @moduledoc """
  Minimal context builder for the agent loop.

  In this first version the context builder reads a static system prompt from
  the project and combines it with inbound message content into structured LLM
  messages.
  """

  alias Nexus.Message

  @doc """
  Builds the provider messages for a single inbound message.
  """
  @spec build_messages(Message.Inbound.t()) :: {:ok, [Message.LLM.t()]} | {:error, term()}
  def build_messages(%Message.Inbound{content: content}) when is_binary(content) do
    with {:ok, system_prompt} <- read_system_prompt() do
      {:ok,
       [
         %Message.LLM{role: :system, content: system_prompt},
         %Message.LLM{role: :user, content: content}
       ]}
    end
  end

  def build_messages(%Message.Inbound{}) do
    {:error, :unsupported_inbound_content}
  end

  defp read_system_prompt do
    path = Application.app_dir(:nexus, "priv/prompts/system.md")

    case File.read(path) do
      {:ok, prompt} ->
        {:ok, String.trim(prompt)}

      {:error, reason} ->
        {:error, {:system_prompt_read_failed, reason}}
    end
  end
end
