defmodule Nexus.ContextBuilderTest do
  use ExUnit.Case

  alias Nexus.ContextBuilder
  alias Nexus.Message.Inbound

  test "build_prompt/1 returns the inbound content when it is a string" do
    inbound = %Inbound{
      session_id: "session_123",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, "hello nexus"} = ContextBuilder.build_prompt(inbound)
  end

  test "build_prompt/1 returns an error for unsupported content" do
    inbound = %Inbound{
      session_id: "session_123",
      channel: :cli,
      content: %{text: "hello nexus"},
      metadata: %{}
    }

    assert {:error, :unsupported_inbound_content} = ContextBuilder.build_prompt(inbound)
  end
end
