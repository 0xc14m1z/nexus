defmodule Mix.Tasks.Nexus.Cli do
  @moduledoc """
  Runs Nexus from the terminal.

  Examples:

      mix nexus.cli "hello nexus"
      mix nexus.cli --session-id session_123 "continue"
      mix nexus.cli
  """

  use Mix.Task

  alias Nexus.CLI

  @shortdoc "Runs Nexus from the terminal"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, remaining, invalid} =
      OptionParser.parse(args,
        strict: [session_id: :string],
        aliases: [s: :session_id]
      )

    case {invalid, remaining} do
      {[], []} ->
        CLI.run_interactive()

      {[], [user_input]} ->
        raw_input = %{
          session_id: Keyword.get(opts, :session_id),
          user_input: user_input
        }

        case CLI.run_once(raw_input) do
          {:ok, outbound} ->
            Mix.shell().info("session_id=#{outbound.session_id}")

          {:error, reason} ->
            Mix.raise("nexus.cli failed: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("""
        usage:
          mix nexus.cli [--session-id session_123] "message text"
          mix nexus.cli
        """)
    end
  end
end
