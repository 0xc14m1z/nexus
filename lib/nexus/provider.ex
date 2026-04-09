defmodule Nexus.Provider do
  @moduledoc """
  Minimal contract for a provider adapter.

  A provider is the boundary between the Nexus runtime and a text generation model.

  In this first version, the contract is intentionally small:

  - the runtime sends a structured `Provider.Request`
  - the provider returns a structured `Provider.Result`

  The request is still text-only for now, but the explicit request/result
  boundary gives the provider path a stable shape before we introduce richer
  metadata, tool execution, or streaming.
  """

  @type config :: map()

  @doc """
  Generates provider output from a structured provider request.

  The provider does not know anything about channels or outbound runtime messages.
  Its job is only to take structured context plus already-resolved configuration
  and return provider output.
  """
  @callback generate(request :: Nexus.Provider.Request.t(), config :: config()) ::
              {:ok, Nexus.Provider.Result.t()} | {:error, term()}
end
