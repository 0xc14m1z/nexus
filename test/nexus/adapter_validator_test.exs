defmodule Nexus.AdapterValidatorTest do
  use ExUnit.Case

  alias Nexus.AdapterValidator
  alias Nexus.Channels.CLI
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory

  test "validate_provider/1 accepts a valid provider" do
    assert :ok = AdapterValidator.validate_provider(Fake)
  end

  test "validate_provider/1 rejects a module that is not a provider" do
    assert {:error, {:invalid_provider, String}} = AdapterValidator.validate_provider(String)
  end

  test "validate_session_store/1 accepts a valid session store" do
    assert :ok = AdapterValidator.validate_session_store(InMemory)
  end

  test "validate_session_store/1 rejects a module that is not a session store" do
    assert {:error, {:invalid_session_store, String}} =
             AdapterValidator.validate_session_store(String)
  end

  test "validate_channel/1 accepts a valid channel" do
    assert :ok = AdapterValidator.validate_channel(CLI)
  end

  test "validate_channel/1 rejects a module that is not a channel" do
    assert {:error, {:invalid_channel, String}} = AdapterValidator.validate_channel(String)
  end
end
