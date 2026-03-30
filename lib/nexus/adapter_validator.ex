defmodule Nexus.AdapterValidator do
  @moduledoc """
  Small runtime validation helper for pluggable adapter modules.

  It exposes domain-oriented validation functions for adapter boundaries and
  keeps the low-level callback checks internal to this module.
  """

  @type callback_spec :: {atom(), non_neg_integer()}

  @doc """
  Validates a provider module.
  """
  @spec validate_provider(module()) :: :ok | {:error, {atom(), module()}}
  def validate_provider(module) do
    validate_callbacks(module, [{:generate, 1}], :invalid_provider)
  end

  @doc """
  Validates a session store module.
  """
  @spec validate_session_store(module()) :: :ok | {:error, {atom(), module()}}
  def validate_session_store(module) do
    validate_callbacks(module, [{:get, 1}, {:save, 1}], :invalid_session_store)
  end

  @doc """
  Validates a channel module.
  """
  @spec validate_channel(module()) :: :ok | {:error, {atom(), module()}}
  def validate_channel(module) do
    validate_callbacks(module, [{:normalize_inbound, 1}, {:deliver, 1}], :invalid_channel)
  end

  @doc """
  Validates a transcript store module.
  """
  @spec validate_transcript_store(module()) :: :ok | {:error, {atom(), module()}}
  def validate_transcript_store(module) do
    validate_callbacks(module, [{:append, 1}, {:list_by_session, 1}], :invalid_transcript_store)
  end

  defp validate_callbacks(module, callbacks, error_tag)
       when is_atom(module) and is_atom(error_tag) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, {error_tag, module}}

      Enum.any?(callbacks, fn {name, arity} -> not function_exported?(module, name, arity) end) ->
        {:error, {error_tag, module}}

      true ->
        :ok
    end
  end

  defp validate_callbacks(module, _callbacks, error_tag) when is_atom(error_tag) do
    {:error, {error_tag, module}}
  end
end
