defmodule Mix.Tasks.Nexus.Chat do
  @moduledoc """
  Runs one Nexus turn from the terminal.

  Examples:

      mix nexus.chat "hello nexus"
      mix nexus.chat --session-id session_123 "continue"
  """

  use Mix.Task

  alias Nexus.CLI
  alias Nexus.SessionStores.InMemory
  alias Nexus.TranscriptStores.InMemory, as: InMemoryTranscriptStore

  @shortdoc "Runs one Nexus chat turn from the terminal"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, remaining, invalid} =
      OptionParser.parse(args,
        strict: [session_id: :string],
        aliases: [s: :session_id]
      )

    case {invalid, remaining} do
      {[], [content]} ->
        raw_input = %{
          session_id: Keyword.get(opts, :session_id),
          content: content
        }

        case CLI.run_once(raw_input, InMemory, InMemoryTranscriptStore) do
          {:ok, outbound} ->
            Mix.shell().info("session_id=#{outbound.session_id}")

          {:error, reason} ->
            Mix.raise("nexus.chat failed: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("""
        usage:
          mix nexus.chat [--session-id session_123] "message text"
        """)
    end
  end
end
