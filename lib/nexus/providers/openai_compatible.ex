defmodule Nexus.Providers.OpenAICompatible do
  @moduledoc """
  Minimal provider adapter for OpenAI-compatible chat endpoints.

  This adapter is intentionally small:

  - it calls `/chat/completions`
  - it supports only text-only `Message.LLM` inputs
  - it returns either final assistant text or a tool request

  The goal is to support local servers such as LM Studio, Ollama's OpenAI
  compatibility layer, and similar runtimes without coupling Nexus to one
  specific local tool.
  """

  @behaviour Nexus.Provider

  alias Nexus.Message
  alias Nexus.Provider

  @default_base_url "http://localhost:1234/v1"
  @default_temperature 0.7

  @impl true
  def generate(%Provider.Request{messages: messages}, config)
      when is_list(messages) and is_map(config) do
    with {:ok, model} <- fetch_model(config),
         {:ok, body} <- build_request_body(messages, model, config),
         {:ok, response} <- post_chat_completions(body, config),
         {:ok, result} <- extract_result(response.body) do
      {:ok, result}
    end
  end

  # OpenAI-compatible servers need a model identifier even when they are local,
  # so we fail early when the runtime configuration does not declare one.
  defp fetch_model(config) do
    case config_get(config, :model) do
      model when is_binary(model) and model != "" -> {:ok, model}
      _missing -> {:error, :missing_openai_compatible_model}
    end
  end

  # The wire format stays close to OpenAI-compatible chat APIs so the adapter
  # remains a thin translation layer from Nexus messages to HTTP payload.
  defp build_request_body(messages, model, config) do
    {:ok,
     %{
       "model" => model,
       "messages" => Enum.map(messages, &message_to_payload/1),
       "temperature" => temperature(config)
     }}
  end

  defp message_to_payload(%Message.LLM{role: role, content: content}) do
    %{
      "role" => Atom.to_string(role),
      "content" => content
    }
  end

  # HTTP execution is injected through `request_fun/1` so tests can validate
  # the mapping without relying on network calls or global mocks.
  defp post_chat_completions(body, config) do
    request_options =
      config
      |> config_get(:request_options, %{})
      |> normalize_request_options()

    request_fun(config).(
      Keyword.merge(
        [
          url: base_url(config) <> "/chat/completions",
          headers: request_headers(config),
          json: body
        ],
        request_options
      )
    )
    |> case do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, %Req.Response{status: status, body: response_body}}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:openai_compatible_request_failed, status, response_body}}

      {:error, reason} ->
        {:error, {:openai_compatible_request_error, reason}}
    end
  end

  # Some local servers run without auth, while hosted OpenAI-compatible
  # endpoints still expect a bearer token, so the auth header is optional.
  defp request_headers(config) do
    [
      {"content-type", "application/json"}
      | authorization_headers(config)
    ]
  end

  defp authorization_headers(config) do
    case config_get(config, :api_key) do
      api_key when is_binary(api_key) and api_key != "" ->
        [{"authorization", "Bearer " <> api_key}]

      _missing ->
        []
    end
  end

  # Tool-capable OpenAI-compatible models return tool calls in the assistant
  # message. We normalize them now even though the agent loop does not execute
  # them yet, so the provider boundary can evolve independently from the loop.
  defp extract_result(%{"choices" => [%{"message" => %{"tool_calls" => tool_calls}} | _rest]})
       when is_list(tool_calls) and tool_calls != [] do
    build_tool_request(tool_calls)
  end

  # Final assistant text remains the common success case for text-only turns.
  defp extract_result(%{"choices" => [%{"message" => %{"content" => content}} | _rest]})
       when is_binary(content) and content != "" do
    {:ok, %Provider.Result.Text{content: content}}
  end

  defp extract_result(%{"choices" => [%{"message" => %{"content" => parts}} | _rest]})
       when is_list(parts) do
    text =
      parts
      |> Enum.filter(&match?(%{"type" => "text", "text" => _}, &1))
      |> Enum.map(& &1["text"])
      |> Enum.join("\n")

    case text do
      "" -> {:error, :openai_compatible_response_missing_text}
      value -> {:ok, %Provider.Result.Text{content: value}}
    end
  end

  defp extract_result(_response_body) do
    {:error, :invalid_openai_compatible_response}
  end

  # Tool-call arguments arrive as JSON strings in the wire format, so we
  # normalize them into maps before they cross the provider boundary.
  defp build_tool_request(tool_calls) do
    Enum.reduce_while(tool_calls, {:ok, []}, fn tool_call, {:ok, acc} ->
      case normalize_tool_call(tool_call) do
        {:ok, normalized_tool_call} -> {:cont, {:ok, [normalized_tool_call | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized_tool_calls} ->
        {:ok, %Provider.Result.ToolRequest{tool_calls: Enum.reverse(normalized_tool_calls)}}

      error ->
        error
    end
  end

  defp normalize_tool_call(%{
         "id" => id,
         "function" => %{"name" => name, "arguments" => arguments_json}
       })
       when is_binary(id) and is_binary(name) and is_binary(arguments_json) do
    case Jason.decode(arguments_json) do
      {:ok, arguments} when is_map(arguments) ->
        {:ok, %{id: id, name: name, arguments: arguments}}

      {:ok, _arguments} ->
        {:error, :invalid_openai_compatible_tool_arguments}

      {:error, _reason} ->
        {:error, :invalid_openai_compatible_tool_arguments}
    end
  end

  defp normalize_tool_call(_tool_call) do
    {:error, :invalid_openai_compatible_tool_call}
  end

  # These accessors keep the string/atom key normalization in one place so the
  # adapter works both with JSON-loaded config and hand-built test config.
  defp base_url(config) do
    config_get(config, :base_url, @default_base_url)
  end

  # Temperature is optional, but we still keep its default in one accessor so
  # request-building code reads like a list of domain fields rather than raw
  # config lookups.
  defp temperature(config) do
    config_get(config, :temperature, @default_temperature)
  end

  defp request_fun(config) do
    config_get(config, :request_fun, &Req.post/1)
  end

  # Runtime config may express request options either as a JSON object or as a
  # keyword list built directly in tests, so we normalize both representations.
  defp normalize_request_options(options) when is_map(options) do
    Enum.map(options, fn {key, value} ->
      normalized_key =
        case key do
          atom when is_atom(atom) -> atom
          binary when is_binary(binary) -> String.to_atom(binary)
        end

      {normalized_key, value}
    end)
  end

  defp normalize_request_options(options) when is_list(options), do: options

  defp normalize_request_options(_other), do: []

  defp config_get(config, key, default \\ nil) when is_map(config) and is_atom(key) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end
end
