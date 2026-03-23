defmodule Nexus.Provider do
  @moduledoc """
  Minimal contract for a provider adapter.

  A provider is the boundary between the Nexus runtime and a text generation model.

  In this first version, the contract is intentionally small:

  - the runtime sends a prompt as a string
  - the provider returns generated text as a string

  This keeps the role of the provider easy to understand before we introduce more
  advanced concepts such as multi-message conversations, tool calls, or streaming.
  """

  @doc """
  Generates text from a prompt string.

  The provider does not know anything about channels or outbound runtime messages.
  Its job is only to take a prompt and return generated text.
  """
  @callback generate(prompt :: String.t()) :: {:ok, String.t()} | {:error, term()}
end
