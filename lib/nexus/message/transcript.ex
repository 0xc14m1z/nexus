defmodule Nexus.Message.Transcript do
  @moduledoc """
  Union type for persisted transcript messages.

  Transcript messages model the persisted conversational history of a session.
  Unlike transport messages or provider-facing LLM messages, they represent the
  canonical items we keep between turns.
  """

  alias Nexus.Message.Transcript.Assistant
  alias Nexus.Message.Transcript.AssistantToolCall
  alias Nexus.Message.Transcript.Tool
  alias Nexus.Message.Transcript.User

  @type t :: User.t() | Assistant.t() | AssistantToolCall.t() | Tool.t()
end
