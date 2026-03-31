defmodule Nexus.Providers.Anthropic do
  @moduledoc """
  Minimal Anthropic provider adapter.

  This first version is intentionally small:

  - it calls the Messages API
  - it supports only text-only `Message.LLM` inputs
  - it maps Nexus system messages to Anthropic's top-level `system` field
  - it returns only the concatenated assistant text

  Configuration is read from application env first, then from environment variables:

  - `:api_key` or `ANTHROPIC_API_KEY`
  - `:model` or `ANTHROPIC_MODEL`
  - `:max_tokens` or `ANTHROPIC_MAX_TOKENS`
  - `:base_url` or `ANTHROPIC_BASE_URL`
  """

  @behaviour Nexus.Provider

  alias Nexus.Message

  @default_base_url "https://api.anthropic.com"
  @default_model "claude-sonnet-4-20250514"
  @default_max_tokens 1024
  @anthropic_version "2023-06-01"

  @impl true
  def generate(messages) when is_list(messages) do
    with {:ok, api_key} <- fetch_api_key(),
         {:ok, body} <- build_request_body(messages),
         {:ok, response} <- post_messages(body, api_key),
         {:ok, generated_text} <- extract_text(response.body) do
      {:ok, generated_text}
    end
  end

  defp fetch_api_key do
    case config(:api_key) || System.get_env("ANTHROPIC_API_KEY") do
      api_key when is_binary(api_key) and api_key != "" -> {:ok, api_key}
      _missing -> {:error, :missing_anthropic_api_key}
    end
  end

  # Anthropic accepts a single initial system prompt, so multiple Nexus system
  # messages are concatenated before sending the request.
  defp build_request_body(messages) do
    {system_messages, conversation_messages} =
      Enum.split_with(messages, &(&1.role == :system))

    body = %{
      "model" => config(:model) || System.get_env("ANTHROPIC_MODEL") || @default_model,
      "max_tokens" => max_tokens(),
      "messages" => Enum.map(conversation_messages, &message_to_payload/1)
    }

    case build_system_prompt(system_messages) do
      nil -> {:ok, body}
      system_prompt -> {:ok, Map.put(body, "system", system_prompt)}
    end
  end

  defp build_system_prompt([]), do: nil

  defp build_system_prompt(system_messages) do
    system_messages
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")
  end

  defp message_to_payload(%Message.LLM{role: role, content: content}) do
    %{
      "role" => Atom.to_string(role),
      "content" => content
    }
  end

  defp post_messages(body, api_key) do
    request_fun().(
      url: base_url() <> "/v1/messages",
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", @anthropic_version},
        {"content-type", "application/json"}
      ],
      json: body
    )
    |> case do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, %Req.Response{status: status, body: response_body}}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:anthropic_request_failed, status, response_body}}

      {:error, reason} ->
        {:error, {:anthropic_request_error, reason}}
    end
  end

  # Anthropic returns an array of content blocks. For the current text-only
  # path, we concatenate all text blocks into the final assistant content.
  defp extract_text(%{"content" => blocks}) when is_list(blocks) do
    text =
      blocks
      |> Enum.filter(&match?(%{"type" => "text", "text" => _}, &1))
      |> Enum.map(& &1["text"])
      |> Enum.join("\n")

    case text do
      "" -> {:error, :anthropic_response_missing_text}
      text -> {:ok, text}
    end
  end

  defp extract_text(_response_body) do
    {:error, :invalid_anthropic_response}
  end

  defp max_tokens do
    case config(:max_tokens) || System.get_env("ANTHROPIC_MAX_TOKENS") do
      nil -> @default_max_tokens
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
    end
  end

  defp base_url do
    config(:base_url) || System.get_env("ANTHROPIC_BASE_URL") || @default_base_url
  end

  defp request_fun do
    config(:request_fun) || (&Req.post/1)
  end

  defp config(key) do
    :nexus
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key)
  end
end
