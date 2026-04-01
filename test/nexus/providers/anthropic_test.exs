defmodule Nexus.Providers.AnthropicTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.Providers.Anthropic

  test "generate/2 returns an error when the api key is missing" do
    messages = [
      %Message.LLM{role: :system, content: "You are Nexus."},
      %Message.LLM{role: :user, content: "hello"}
    ]

    assert {:error, :missing_anthropic_api_key} = Anthropic.generate(messages, %{})
  end

  test "generate/2 maps Nexus messages to an Anthropic request and returns text content" do
    parent = self()

    request_fun = fn opts ->
      send(parent, {:request_opts, opts})

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "content" => [
             %{"type" => "text", "text" => "hello from anthropic"}
           ]
         }
       }}
    end

    config = %{
      api_key: "test-key",
      model: "claude-sonnet-4-20250514",
      max_tokens: 256,
      base_url: "https://example.test",
      request_fun: request_fun
    }

    messages = [
      %Message.LLM{role: :system, content: "System one."},
      %Message.LLM{role: :system, content: "System two."},
      %Message.LLM{role: :user, content: "hello"},
      %Message.LLM{role: :assistant, content: "previous answer"},
      %Message.LLM{role: :user, content: "continue"}
    ]

    assert {:ok, "hello from anthropic"} = Anthropic.generate(messages, config)

    assert_received {:request_opts, opts}

    assert Keyword.fetch!(opts, :url) == "https://example.test/v1/messages"
    assert {"x-api-key", "test-key"} in Keyword.fetch!(opts, :headers)
    assert {"anthropic-version", "2023-06-01"} in Keyword.fetch!(opts, :headers)

    assert Keyword.fetch!(opts, :json) == %{
             "model" => "claude-sonnet-4-20250514",
             "max_tokens" => 256,
             "system" => "System one.\n\nSystem two.",
             "messages" => [
               %{"role" => "user", "content" => "hello"},
               %{"role" => "assistant", "content" => "previous answer"},
               %{"role" => "user", "content" => "continue"}
             ]
           }
  end
end
