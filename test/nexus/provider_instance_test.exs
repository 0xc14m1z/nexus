defmodule Nexus.ProviderInstanceTest do
  use ExUnit.Case

  alias Nexus.ProviderInstance
  alias Nexus.Message
  alias Nexus.Providers.Fake

  test "new/2 builds a provider instance from a valid adapter" do
    assert {:ok, %ProviderInstance{adapter: Fake, config: %{mode: :test}}} =
             ProviderInstance.new(Fake, %{mode: :test})
  end

  test "new/2 rejects an adapter that does not implement the provider behaviour" do
    assert {:error, {:invalid_provider, String}} = ProviderInstance.new(String, %{})
  end

  test "generate/2 delegates to the configured adapter" do
    provider = %ProviderInstance{adapter: Fake, config: %{}}

    messages = [
      %Message.LLM{role: :system, content: "You are Nexus."},
      %Message.LLM{role: :user, content: "hello nexus"}
    ]

    assert {:ok, "Fake response: System:\nYou are Nexus.\n\nUser:\nhello nexus"} =
             ProviderInstance.generate(provider, messages)
  end
end
