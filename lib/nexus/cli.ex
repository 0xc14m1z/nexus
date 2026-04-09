defmodule Nexus.CLI do
  @moduledoc """
  Small CLI-facing entrypoint for running one Nexus turn.

  This module bridges the CLI channel with the high-level `Nexus.run/2`
  runtime entrypoint:

  - normalize raw CLI input
  - execute one turn through the runtime
  - deliver the outbound reply back to the terminal

  It also exposes a tiny interactive loop for manual local testing.
  """

  alias Nexus.Channels.CLI, as: CLIChannel
  alias Nexus.Message

  @doc """
  Runs one CLI turn from a raw payload.

  Expected input:

      %{session_id: nil | "session_123", user_input: "hello"}
  """
  def run_once(raw_input, opts \\ [])

  @spec run_once(map(), keyword()) :: {:ok, Message.Outbound.t()} | {:error, term()}
  def run_once(raw_input, opts) when is_map(raw_input) and is_list(opts) do
    with {:ok, inbound} <- CLIChannel.normalize_inbound(raw_input),
         {:ok, outbound} <- run_nexus(inbound, opts),
         :ok <- CLIChannel.deliver(outbound) do
      {:ok, outbound}
    end
  end

  def run_once(_raw_input, _opts) do
    {:error, :invalid_cli_input}
  end

  @doc """
  Runs a small interactive CLI loop in the current VM.

  Special commands:

      /new   starts a new session
      /exit  exits the loop
  """
  @spec run_interactive(keyword()) :: :ok
  def run_interactive(opts \\ []) when is_list(opts) do
    IO.puts("Nexus interactive chat")
    IO.puts("Commands: /new, /exit")

    interactive_loop(nil, opts)
  end

  # The interactive loop keeps the current session id in memory so repeated
  # turns in the same VM can reuse the persisted transcript.
  defp interactive_loop(session_id, opts) do
    case IO.gets(prompt(session_id)) do
      nil ->
        :ok

      line ->
        line
        |> String.trim()
        |> handle_interactive_input(session_id, opts)
    end
  end

  # Empty lines are ignored so the operator can press enter without changing
  # the current session or producing noisy transcript entries.
  defp handle_interactive_input("", session_id, opts) do
    interactive_loop(session_id, opts)
  end

  # `/exit` stops the manual loop without affecting persisted state.
  defp handle_interactive_input("/exit", _session_id, _opts) do
    IO.puts("bye")
    :ok
  end

  # `/new` discards only the in-memory session pointer so the next turn will
  # create a fresh session through the normal runtime path.
  defp handle_interactive_input("/new", _session_id, opts) do
    IO.puts("started new session")
    interactive_loop(nil, opts)
  end

  # Any other line is treated as raw user input for the current session.
  defp handle_interactive_input(user_input, session_id, opts) do
    case run_once(%{session_id: session_id, user_input: user_input}, opts) do
      {:ok, outbound} ->
        IO.puts("session_id=#{outbound.session_id}")
        interactive_loop(outbound.session_id, opts)

      {:error, reason} ->
        IO.puts("error=#{inspect(reason)}")
        interactive_loop(session_id, opts)
    end
  end

  # The prompt mirrors the current session pointer so manual testing makes it
  # obvious whether the next turn will reuse an existing transcript.
  defp prompt(nil), do: "nexus> "
  defp prompt(session_id), do: "nexus(#{session_id})> "

  # The CLI keeps runtime config lookup centralized in `Nexus`, but a manual
  # config path can override the default lookup order for smoke tests.
  defp run_nexus(inbound, opts) do
    Nexus.run(inbound, opts)
  end
end
