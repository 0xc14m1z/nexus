defmodule Nexus.Providers.Fake do
  @moduledoc """
  Minimal deterministic provider used for development and learning.

  This provider does not call any external API.
  It simply echoes the received prompt with a fixed prefix so the behavior stays
  easy to understand and easy to test.
  """

  @behaviour Nexus.Provider

  @impl true
  def generate(prompt) when is_binary(prompt) do
    {:ok, "Fake response: " <> prompt}
  end
end
