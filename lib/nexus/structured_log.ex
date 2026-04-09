defmodule Nexus.StructuredLog do
  @moduledoc """
  Helpers for structured runtime diagnostics.

  This module keeps JSON-friendly event shaping separate from CLI rendering so
  the same payload can later feed structured logs, external tooling, or other
  channels without duplicating formatting logic.
  """

  alias Nexus.Message

  @doc """
  Builds a structured debug event from one outbound message.
  """
  @spec turn_debug(Message.Outbound.t()) :: map()
  def turn_debug(%Message.Outbound{session_id: session_id, channel: channel, metadata: metadata}) do
    %{
      "event" => "nexus.turn.debug",
      "session_id" => session_id,
      "channel" => Atom.to_string(channel),
      "debug" => normalize_debug(Map.get(metadata, :debug, %{}))
    }
  end

  # Debug payloads already arrive sanitized from the orchestrator; here we only
  # normalize structs and atoms so they become JSON-friendly.
  defp normalize_debug(debug) when is_map(debug) do
    Map.new(debug, fn {key, value} ->
      {to_string(key), normalize_debug_value(value)}
    end)
  end

  defp normalize_debug(_other), do: %{}

  defp normalize_debug_value(%Message.LLM{role: role, content: content}) do
    %{
      "role" => Atom.to_string(role),
      "content" => content
    }
  end

  defp normalize_debug_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), normalize_debug_value(nested_value)}
    end)
  end

  defp normalize_debug_value(value) when is_list(value) do
    Enum.map(value, &normalize_debug_value/1)
  end

  defp normalize_debug_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_debug_value(value), do: value
end
