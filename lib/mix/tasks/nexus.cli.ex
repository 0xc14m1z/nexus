defmodule Mix.Tasks.Nexus.Cli do
  @moduledoc """
  Runs Nexus from the terminal.

  Examples:

      mix nexus.cli "hello nexus"
      mix nexus.cli --session-id session_123 "continue"
      mix nexus.cli --config config/nexus.local.json "hello nexus"
      mix nexus.cli --debug "hello nexus"
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
        strict: [session_id: :string, config: :string, debug: :boolean],
        aliases: [s: :session_id, c: :config, d: :debug]
      )

    cli_opts =
      []
      |> maybe_put_cli_opt(:config_path, Keyword.get(opts, :config))
      |> maybe_put_cli_opt(:debug, Keyword.get(opts, :debug, false))

    case {invalid, remaining} do
      {[], []} ->
        CLI.run_interactive(cli_opts)

      {[], [user_input]} ->
        raw_input = %{
          session_id: Keyword.get(opts, :session_id),
          user_input: user_input
        }

        case CLI.run_once(raw_input, cli_opts) do
          {:ok, outbound} ->
            Mix.shell().info("session_id=#{outbound.session_id}")

          {:error, reason} ->
            Mix.raise("nexus.cli failed: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("""
        usage:
          mix nexus.cli [--config path/to/config.json] [--debug] [--session-id session_123] "message text"
          mix nexus.cli
        """)
    end
  end

  # CLI options are assembled only when present so the downstream runtime code
  # sees a clean keyword list instead of placeholder values.
  defp maybe_put_cli_opt(opts, _key, nil), do: opts
  defp maybe_put_cli_opt(opts, _key, false), do: opts
  defp maybe_put_cli_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
