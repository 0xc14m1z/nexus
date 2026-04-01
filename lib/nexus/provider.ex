defmodule Nexus.Provider do
  @moduledoc """
  Minimal contract for a provider adapter.

  A provider is the boundary between the Nexus runtime and a text generation model.

  In this first version, the contract is intentionally small:

  - the runtime sends a list of internal LLM messages
  - the provider returns generated text as a string

  This keeps the role of the provider easy to understand before we introduce more
  advanced concepts such as multi-message conversations, tool calls, or streaming.
  """

  alias Nexus.Message

  @type config :: map()

  @doc """
  Generates text from a list of LLM messages.

  The provider does not know anything about channels or outbound runtime messages.
  Its job is only to take structured context plus already-resolved configuration
  and return generated text.
  """
  @callback generate(messages :: [Message.LLM.t()], config :: config()) ::
              {:ok, String.t()} | {:error, term()}
end
