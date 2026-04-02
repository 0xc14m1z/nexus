defmodule Nexus.CLI do
  @moduledoc """
  Small CLI-facing entrypoint for running one Nexus turn.

  This module bridges the CLI channel with the high-level `Nexus.run/3`
  runtime entrypoint:

  - normalize raw CLI input
  - execute one turn through the runtime
  - deliver the outbound reply back to the terminal
  """

  alias Nexus.Channels.CLI, as: CLIChannel
  alias Nexus.Message

  @doc """
  Runs one CLI turn from a raw payload.

  Expected input:

      %{session_id: nil | "session_123", content: "hello"}
  """
  @spec run_once(map(), module(), module()) :: {:ok, Message.Outbound.t()} | {:error, term()}
  def run_once(raw_input, session_store, transcript_store) when is_map(raw_input) do
    with {:ok, inbound} <- CLIChannel.normalize_inbound(raw_input),
         {:ok, outbound} <- Nexus.run(inbound, session_store, transcript_store),
         :ok <- CLIChannel.deliver(outbound) do
      {:ok, outbound}
    end
  end

  def run_once(_raw_input, _session_store, _transcript_store) do
    {:error, :invalid_cli_input}
  end
end
