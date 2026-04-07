defmodule Nexus.Channels.CLI do
  @moduledoc """
  Minimal CLI channel adapter.

  This first version is intentionally simple:

  - the raw input is a map
  - the caller provides `session_id` and `user_input`
  - the channel normalizes that input into `%Nexus.Message.Inbound{}`
  - outbound messages are printed to standard output

  The important idea is that the channel does not decide the session.
  It only copies the provided `session_id` into the internal message shape.
  """

  @behaviour Nexus.Channel

  alias Nexus.Message

  @doc """
  Normalizes a minimal CLI payload into an inbound message.

  Expected input:

      %{session_id: nil | "session_123", user_input: "hello"}

  Optional fields:

      %{metadata: %{...}}
  """
  @impl true
  def normalize_inbound(%{session_id: session_id, user_input: user_input} = raw)
      when (is_binary(session_id) or is_nil(session_id)) and not is_nil(user_input) do
    {:ok,
     %Message.Inbound{
       session_id: session_id,
       channel: :cli,
       content: user_input,
       metadata: Map.get(raw, :metadata, %{})
     }}
  end

  def normalize_inbound(_raw) do
    {:error, :invalid_cli_input}
  end

  @doc """
  Delivers an outbound message by printing its content.
  """
  @impl true
  def deliver(%Message.Outbound{content: content}) do
    IO.puts(format_content(content))
    :ok
  end

  # Outbound delivery can print either plain text or inspected data structures
  # without the rest of the runtime needing to care about terminal formatting.
  defp format_content(content) when is_binary(content), do: content
  defp format_content(content), do: inspect(content)
end
