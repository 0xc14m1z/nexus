defmodule Nexus.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Nexus.Message.Inbound
  alias Nexus.Orchestrator
  alias Nexus.Providers.Fake
  alias Nexus.Session
  alias Nexus.SessionStores.InMemory

  setup do
    InMemory.clear()
    :ok
  end

  test "run/3 creates a session through the store when the inbound message has no session id" do
    inbound = %Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory)
    assert is_binary(outbound.session_id)
    assert {:ok, %Session{id: id}} = InMemory.get(outbound.session_id)
    assert id == outbound.session_id
  end

  test "run/3 reuses an existing session from the store" do
    assert {:ok, %Session{id: session_id}} = InMemory.save(%Session{})

    inbound = %Inbound{
      session_id: session_id,
      channel: :cli,
      content: "hello again",
      metadata: %{}
    }

    assert {:ok, outbound} = Orchestrator.run(inbound, Fake, InMemory)
    assert outbound.session_id == session_id
  end

  test "run/3 returns an error when the requested session does not exist" do
    inbound = %Inbound{
      session_id: "session_missing",
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, :session_not_found} = Orchestrator.run(inbound, Fake, InMemory)
  end

  test "run/3 returns an invalid session store error for a module that is not a session store" do
    inbound = %Inbound{
      session_id: nil,
      channel: :cli,
      content: "hello nexus",
      metadata: %{}
    }

    assert {:error, {:invalid_session_store, String}} =
             Orchestrator.run(inbound, Fake, String)
  end
end
