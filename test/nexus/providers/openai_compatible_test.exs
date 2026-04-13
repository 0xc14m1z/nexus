defmodule Nexus.Providers.OpenAICompatibleTest do
  use ExUnit.Case, async: false

  alias Nexus.Message
  alias Nexus.Provider
  alias Nexus.Providers.OpenAICompatible

  test "generate/2 returns an error when the model is missing" do
    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :system, content: "You are Nexus."},
        %Message.LLM{role: :user, content: "hello"}
      ]
    }

    assert {:error, :missing_openai_compatible_model} =
             OpenAICompatible.generate(request, %{})
  end

  test "generate/2 maps Nexus messages to a chat completions request and returns text content" do
    parent = self()

    request_fun = fn opts ->
      send(parent, {:request_opts, opts})

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "hello from openai-compatible"
               }
             }
           ]
         }
       }}
    end

    config = %{
      api_key: "test-key",
      model: "openai/gpt-oss-20b",
      temperature: 0.2,
      base_url: "http://localhost:1234/v1",
      request_fun: request_fun
    }

    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :system, content: "System one."},
        %Message.LLM{role: :user, content: "hello"},
        %Message.LLM{role: :assistant, content: "previous answer"},
        %Message.LLM{role: :user, content: "continue"}
      ],
      tools: [
        %{
          name: "current_time",
          description: "Get the current UTC time as an ISO8601 timestamp.",
          input_schema: %{
            "type" => "object",
            "properties" => %{},
            "additionalProperties" => false
          }
        }
      ]
    }

    assert {:ok, %Provider.Result.Text{content: "hello from openai-compatible"}} =
             OpenAICompatible.generate(request, config)

    assert_received {:request_opts, opts}

    assert Keyword.fetch!(opts, :url) == "http://localhost:1234/v1/chat/completions"
    assert {"authorization", "Bearer test-key"} in Keyword.fetch!(opts, :headers)

    assert Keyword.fetch!(opts, :json) == %{
             "model" => "openai/gpt-oss-20b",
             "temperature" => 0.2,
             "tools" => [
               %{
                 "type" => "function",
                 "function" => %{
                   "name" => "current_time",
                   "description" => "Get the current UTC time as an ISO8601 timestamp.",
                   "parameters" => %{
                     "type" => "object",
                     "properties" => %{},
                     "additionalProperties" => false
                   }
                 }
               }
             ],
             "messages" => [
               %{"role" => "system", "content" => "System one."},
               %{"role" => "user", "content" => "hello"},
               %{"role" => "assistant", "content" => "previous answer"},
               %{"role" => "user", "content" => "continue"}
             ]
           }
  end

  test "generate/2 omits the authorization header when the api key is missing" do
    parent = self()

    request_fun = fn opts ->
      send(parent, {:request_opts, opts})

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "hello from local server"
               }
             }
           ]
         }
       }}
    end

    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :user, content: "hello"}
      ]
    }

    assert {:ok, %Provider.Result.Text{content: "hello from local server"}} =
             OpenAICompatible.generate(request, %{
               "model" => "openai/gpt-oss-20b",
               "base_url" => "http://localhost:1234/v1",
               request_fun: request_fun
             })

    assert_received {:request_opts, opts}

    refute Enum.any?(Keyword.fetch!(opts, :headers), fn {name, _value} ->
             String.downcase(name) == "authorization"
           end)
  end

  test "generate/2 merges request_options from JSON-style config" do
    parent = self()

    request_fun = fn opts ->
      send(parent, {:request_opts, opts})

      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "choices" => [
             %{
               "message" => %{
                 "content" => "hello with custom timeouts"
               }
             }
           ]
         }
       }}
    end

    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :user, content: "hello"}
      ]
    }

    assert {:ok, %Provider.Result.Text{content: "hello with custom timeouts"}} =
             OpenAICompatible.generate(request, %{
               "model" => "nvidia/nemotron-3-nano-4b",
               "base_url" => "http://localhost:1234/v1",
               "request_options" => %{
                 "receive_timeout" => 30_000,
                 "connect_options" => %{"timeout" => 5_000}
               },
               request_fun: request_fun
             })

    assert_received {:request_opts, opts}

    assert Keyword.fetch!(opts, :receive_timeout) == 30_000
    assert Keyword.fetch!(opts, :connect_options) == %{"timeout" => 5_000}
  end

  test "generate/2 returns a tool-request result when the model asks for tools" do
    request_fun = fn _opts ->
      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "choices" => [
             %{
               "message" => %{
                 "tool_calls" => [
                   %{
                     "id" => "call_123",
                     "type" => "function",
                     "function" => %{
                       "name" => "current_time",
                       "arguments" => "{}"
                     }
                   }
                 ]
               }
             }
           ]
         }
       }}
    end

    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :user, content: "What time is it?"}
      ],
      tools: [
        %{
          name: "current_time",
          description: "Get the current UTC time as an ISO8601 timestamp.",
          input_schema: %{
            "type" => "object",
            "properties" => %{},
            "additionalProperties" => false
          }
        }
      ]
    }

    assert {:ok,
            %Provider.Result.ToolRequest{
              tool_calls: [
                %{id: "call_123", name: "current_time", arguments: %{}}
              ]
            }} =
             OpenAICompatible.generate(request, %{
               "model" => "nvidia/nemotron-3-nano-4b",
               "base_url" => "http://localhost:1234/v1",
               request_fun: request_fun
             })
  end
end
