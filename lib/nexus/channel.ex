defmodule Nexus.Channel do
  @moduledoc """
  Minimal contract for a channel adapter.

  A channel is the boundary between the outside world and the Nexus runtime.

  In this first version, a channel has only two responsibilities:

  - convert external input into `%Nexus.Message.Inbound{}`
  - deliver `%Nexus.Message.Outbound{}` back to the outside world

  We intentionally keep this behaviour small so the role of a channel stays clear
  while we are still learning the architecture.
  """

  alias Nexus.Message

  @doc """
  Converts raw channel input into the internal inbound message format.

  Each adapter can receive its own raw input shape. For example:

  - a CLI adapter may receive a plain string
  - a Telegram adapter may receive a map decoded from an update payload
  - another adapter may receive a richer custom structure

  The job of the channel is to normalize that raw input into a common
  `%Nexus.Message.Inbound{}` struct that the rest of the runtime can understand.
  """
  @callback normalize_inbound(raw :: term()) :: {:ok, Message.Inbound.t()} | {:error, term()}

  @doc """
  Delivers an internal outbound message through the external channel.

  At this stage the runtime does not care how delivery happens. It only knows that
  it has produced a `%Nexus.Message.Outbound{}` and that the channel adapter is
  responsible for getting it back out.
  """
  @callback deliver(message :: Message.Outbound.t()) :: :ok | {:error, term()}
end
