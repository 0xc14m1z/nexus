defmodule Nexus.Providers.Anthropic do
  @moduledoc """
  Minimal Anthropic provider adapter.

  This first version is intentionally small:

  - it calls the Messages API
  - it supports only text-only `Message.LLM` inputs
  - it maps Nexus system messages to Anthropic's top-level `system` field
  - it returns either concatenated assistant text or a tool request

  All configuration must be passed in from the outside. This keeps environment
  lookup and application bootstrapping out of the provider adapter itself.
  """

  @behaviour Nexus.Provider

  alias Nexus.Message
  alias Nexus.Provider

  @default_base_url "https://api.anthropic.com"
  @default_model "claude-sonnet-4-20250514"
  @default_max_tokens 1024
  @anthropic_version "2023-06-01"

  @impl true
  def generate(%Provider.Request{messages: messages}, config)
      when is_list(messages) and is_map(config) do
    with {:ok, api_key} <- fetch_api_key(config),
         {:ok, body} <- build_request_body(messages, config),
         {:ok, response} <- post_messages(body, api_key, config),
         {:ok, result} <- extract_result(response.body) do
      {:ok, result}
    end
  end

  # Runtime configuration may come from JSON, so we accept either atom keys or
  # string keys when retrieving the API key.
  defp fetch_api_key(config) do
    case config_get(config, :api_key) do
      api_key when is_binary(api_key) and api_key != "" -> {:ok, api_key}
      _missing -> {:error, :missing_anthropic_api_key}
    end
  end

  # Anthropic accepts a single initial system prompt, so multiple Nexus system
  # messages are concatenated before sending the request.
  defp build_request_body(messages, config) do
    {system_messages, conversation_messages} =
      Enum.split_with(messages, &(&1.role == :system))

    body = %{
      "model" => config_get(config, :model, @default_model),
      "max_tokens" => max_tokens(config),
      "messages" => Enum.map(conversation_messages, &message_to_payload/1)
    }

    case build_system_prompt(system_messages) do
      nil -> {:ok, body}
      system_prompt -> {:ok, Map.put(body, "system", system_prompt)}
    end
  end

  defp build_system_prompt([]), do: nil

  # Multiple internal system messages are flattened into one string because
  # Anthropic exposes a single top-level `system` field.
  defp build_system_prompt(system_messages) do
    system_messages
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")
  end

  # Conversation messages stay close to Anthropic's wire format, so the
  # adapter mostly performs key conversion here.
  defp message_to_payload(%Message.LLM{role: role, content: content}) do
    %{
      "role" => Atom.to_string(role),
      "content" => content
    }
  end

  # Request execution is isolated behind `request_fun/1` so tests can replace
  # the HTTP client without mocking global state.
  defp post_messages(body, api_key, config) do
    request_fun(config).(
      url: base_url(config) <> "/v1/messages",
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

  defp extract_result(%{"content" => blocks}) when is_list(blocks) do
    case build_tool_request(blocks) do
      {:ok, %Provider.Result.ToolRequest{} = tool_request} ->
        {:ok, tool_request}

      :no_tool_use ->
        build_text_result(blocks)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_result(_response_body) do
    {:error, :invalid_anthropic_response}
  end

  # When Anthropic returns one or more `tool_use` blocks, they become the
  # provider result for this turn and the agent loop decides what to do next.
  defp build_tool_request(blocks) do
    tool_calls =
      blocks
      |> Enum.filter(&match?(%{"type" => "tool_use"}, &1))
      |> Enum.map(&normalize_tool_use/1)

    cond do
      tool_calls == [] ->
        :no_tool_use

      Enum.all?(tool_calls, &match?({:ok, _}, &1)) ->
        {:ok,
         %Provider.Result.ToolRequest{
           tool_calls:
             tool_calls
             |> Enum.map(fn {:ok, tool_call} -> tool_call end)
         }}

      true ->
        {:error, :invalid_anthropic_tool_use}
    end
  end

  defp normalize_tool_use(%{
         "type" => "tool_use",
         "id" => id,
         "name" => name,
         "input" => input
       })
       when is_binary(id) and is_binary(name) and is_map(input) do
    {:ok, %{id: id, name: name, arguments: input}}
  end

  defp normalize_tool_use(_tool_use) do
    {:error, :invalid_anthropic_tool_use}
  end

  # If no tool request is present, Anthropic content blocks collapse to the
  # assistant text we already used before this slice.
  defp build_text_result(blocks) do
    text =
      blocks
      |> Enum.filter(&match?(%{"type" => "text", "text" => _}, &1))
      |> Enum.map(& &1["text"])
      |> Enum.join("\n")

    case text do
      "" -> {:error, :anthropic_response_missing_text}
      text -> {:ok, %Provider.Result.Text{content: text}}
    end
  end

  # These small accessors keep defaults in one place and hide the atom/string
  # key normalization done by `config_get/3`.
  defp max_tokens(config) do
    config_get(config, :max_tokens, @default_max_tokens)
  end

  defp base_url(config) do
    config_get(config, :base_url, @default_base_url)
  end

  defp request_fun(config) do
    config_get(config, :request_fun, &Req.post/1)
  end

  # JSON-loaded config uses string keys, while tests and code often use atom
  # keys, so we accept both representations transparently.
  defp config_get(config, key, default \\ nil) when is_map(config) and is_atom(key) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end
end
