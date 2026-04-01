defmodule Nexus.Providers.Fake do
  @moduledoc """
  Minimal deterministic provider used for development and learning.

  This provider does not call any external API.
  It simply renders the received messages with a fixed prefix so the behavior stays
  easy to understand and easy to test.
  """

  @behaviour Nexus.Provider

  alias Nexus.Message

  @impl true
  def generate(messages, _config) when is_list(messages) do
    rendered_messages =
      messages
      |> Enum.map(&render_message/1)
      |> Enum.join("\n\n")

    {:ok, "Fake response: " <> rendered_messages}
  end

  defp render_message(%Message.LLM{role: role, content: content}) do
    "#{format_role(role)}:\n#{content}"
  end

  defp format_role(:system), do: "System"
  defp format_role(:user), do: "User"
  defp format_role(:assistant), do: "Assistant"
end
