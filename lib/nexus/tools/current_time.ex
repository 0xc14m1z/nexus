defmodule Nexus.Tools.CurrentTime do
  @moduledoc """
  Simple built-in tool that returns the current UTC time.

  This is intentionally small but still genuinely useful: it gives the model
  access to real external state without opening broader file or shell access.
  """

  @behaviour Nexus.Tool

  @impl true
  def definition(_config) do
    %{
      name: "current_time",
      description: "Get the current UTC time as an ISO8601 timestamp.",
      input_schema: %{
        "type" => "object",
        "properties" => %{},
        "additionalProperties" => false
      }
    }
  end

  @impl true
  def call(arguments, _config) when is_map(arguments) do
    case map_size(arguments) do
      0 ->
        {:ok, DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()}

      _ ->
        {:error, :current_time_takes_no_arguments}
    end
  end
end
