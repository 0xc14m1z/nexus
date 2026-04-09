defmodule Nexus.ProviderInstanceTest do
  use ExUnit.Case

  alias Nexus.ProviderInstance
  alias Nexus.Provider
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

    request = %Provider.Request{
      messages: [
        %Message.LLM{role: :system, content: "You are Nexus."},
        %Message.LLM{role: :user, content: "hello nexus"}
      ]
    }

    assert {:ok,
            %Provider.Result{
              content: "Fake response: System:\nYou are Nexus.\n\nUser:\nhello nexus"
            }} =
             ProviderInstance.generate(provider, request)
  end
end
