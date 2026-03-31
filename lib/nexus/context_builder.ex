defmodule Nexus.ContextBuilder do
  @moduledoc """
  Minimal context builder for the agent loop.

  In this first version the context builder reads a static system prompt from
  the project and combines it with the persisted session transcript into
  structured LLM messages.
  """

  alias Nexus.Message

  @doc """
  Builds the provider messages for a single agent turn from transcript history.
  """
  @spec build_messages([Message.Transcript.t()]) :: {:ok, [Message.LLM.t()]} | {:error, term()}
  def build_messages(transcript_messages) when is_list(transcript_messages) do
    with {:ok, system_prompt} <- read_system_prompt(),
         {:ok, llm_messages} <- build_transcript_messages(transcript_messages) do
      {:ok, [%Message.LLM{role: :system, content: system_prompt} | llm_messages]}
    end
  end

  def build_messages(_transcript_messages) do
    {:error, :invalid_transcript_messages}
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

  # Keeps the external order of the transcript while allowing us to build the
  # result with an efficient prepend during the reduce.
  defp build_transcript_messages(transcript_messages) do
    Enum.reduce_while(transcript_messages, {:ok, []}, fn message, {:ok, acc} ->
      case transcript_to_llm(message) do
        {:ok, llm_message} -> {:cont, {:ok, [llm_message | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, messages} -> {:ok, Enum.reverse(messages)}
      error -> error
    end
  end

  # User transcript messages become normal user-role LLM messages.
  defp transcript_to_llm(%Message.Transcript.User{content: content}) do
    {:ok, %Message.LLM{role: :user, content: content}}
  end

  # Assistant transcript messages become assistant-role LLM messages so the
  # next turn can see previous assistant replies.
  defp transcript_to_llm(%Message.Transcript.Assistant{content: content}) do
    {:ok, %Message.LLM{role: :assistant, content: content}}
  end

  # Tool-related transcript messages are intentionally unsupported until the
  # agent loop knows how to produce and consume them correctly.
  defp transcript_to_llm(_message) do
    {:error, :unsupported_transcript_message}
  end
end
