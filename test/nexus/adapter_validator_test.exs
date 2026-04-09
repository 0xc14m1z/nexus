defmodule Nexus.AdapterValidatorTest do
  use ExUnit.Case

  alias Nexus.AdapterValidator
  alias Nexus.Channels.CLI
  alias Nexus.Providers.Fake
  alias Nexus.SessionStores.InMemory, as: InMemorySessionStore
  alias Nexus.Tools.CurrentTime
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  test "validate_provider/1 accepts a valid provider" do
    assert :ok = AdapterValidator.validate_provider(Fake)
  end

  test "validate_provider/1 rejects a module that is not a provider" do
    assert {:error, {:invalid_provider, String}} = AdapterValidator.validate_provider(String)
  end

  test "validate_session_store/1 accepts a valid session store" do
    assert :ok = AdapterValidator.validate_session_store(InMemorySessionStore)
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

  test "validate_transcript_store/1 accepts a valid transcript store" do
    assert :ok = AdapterValidator.validate_transcript_store(InMemoryTranscriptStore)
  end

  test "validate_transcript_store/1 rejects a module that is not a transcript store" do
    assert {:error, {:invalid_transcript_store, String}} =
             AdapterValidator.validate_transcript_store(String)
  end

  test "validate_tool/1 accepts a valid tool" do
    assert :ok = AdapterValidator.validate_tool(CurrentTime)
  end

  test "validate_tool/1 rejects a module that is not a tool" do
    assert {:error, {:invalid_tool, String}} = AdapterValidator.validate_tool(String)
  end
end
