defmodule Nexus.Providers.OpenAICompatible do
  @moduledoc """
  Minimal provider adapter for OpenAI-compatible chat endpoints.

  This adapter is intentionally small:

  - it calls `/chat/completions`
  - it supports only text-only `Message.LLM` inputs
  - it returns only the first assistant message content

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
         {:ok, generated_text} <- extract_text(response.body) do
      {:ok, %Provider.Result{content: generated_text}}
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

  # The first implementation extracts only the first assistant text because the
  # current Nexus provider contract returns one final string.
  defp extract_text(%{"choices" => [%{"message" => %{"content" => content}} | _rest]})
       when is_binary(content) and content != "" do
    {:ok, content}
  end

  defp extract_text(%{"choices" => [%{"message" => %{"content" => parts}} | _rest]})
       when is_list(parts) do
    text =
      parts
      |> Enum.filter(&match?(%{"type" => "text", "text" => _}, &1))
      |> Enum.map(& &1["text"])
      |> Enum.join("\n")

    case text do
      "" -> {:error, :openai_compatible_response_missing_text}
      value -> {:ok, value}
    end
  end

  defp extract_text(_response_body) do
    {:error, :invalid_openai_compatible_response}
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
