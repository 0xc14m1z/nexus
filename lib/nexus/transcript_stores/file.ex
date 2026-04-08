defmodule Nexus.TranscriptStores.File do
  @moduledoc """
  File-backed `TranscriptStore` adapter.

  Each session transcript is stored as a JSONL file where every line represents
  one persisted transcript message. This keeps append semantics cheap and makes
  the transcript easy to inspect by hand during development.
  """

  @behaviour Nexus.TranscriptStore

  alias Nexus.Message

  @default_directory "var/nexus/transcripts"

  defguardp is_transcript_message(message)
            when is_struct(message, Message.Transcript.User) or
                   is_struct(message, Message.Transcript.Assistant) or
                   is_struct(message, Message.Transcript.AssistantToolCall) or
                   is_struct(message, Message.Transcript.Tool)

  @impl true
  def append(message, config) when is_transcript_message(message) and is_map(config) do
    with :ok <- ensure_directory(config),
         {:ok, encoded} <- encode_message(persistable_message(message)),
         {:ok, json_line} <- Jason.encode(encoded),
         :ok <- append_line(transcript_path(message.session_id, config), json_line) do
      decode_message(encoded)
    end
  end

  @impl true
  def list_by_session(session_id, config) when is_binary(session_id) and is_map(config) do
    with :ok <- ensure_directory(config),
         {:ok, lines} <- read_lines(transcript_path(session_id, config)),
         {:ok, messages} <- decode_lines(lines) do
      {:ok, Enum.sort_by(messages, &DateTime.to_unix(&1.inserted_at, :microsecond))}
    end
  end

  @doc """
  Clears all persisted transcript files in the configured directory.

  This helper is mainly useful in tests and local manual resets.
  """
  @spec clear(map()) :: :ok | {:error, term()}
  def clear(config \\ %{}) do
    with :ok <- ensure_directory(config),
         {:ok, entries} <- File.ls(directory(config)) do
      Enum.reduce_while(entries, :ok, fn entry, :ok ->
        case File.rm(Path.join(directory(config), entry)) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {:transcript_store_clear_failed, reason}}}
        end
      end)
    end
  end

  # Transcript messages may already carry ids or timestamps, but the store
  # fills them in when missing so append semantics stay convenient.
  defp persistable_message(message) when is_transcript_message(message) do
    now = DateTime.utc_now()

    struct(message, %{
      id: Map.get(message, :id) || build_id(),
      inserted_at: Map.get(message, :inserted_at) || now
    })
  end

  # The file-backed transcript adapter uses a simple monotonic id because the
  # main requirement is stable identity within one local runtime.
  defp build_id do
    "message_" <> Integer.to_string(System.unique_integer([:positive]))
  end

  # File-backed transcript stores rely on an explicit directory so the runtime
  # can decide where conversation history should live.
  defp ensure_directory(config) do
    case File.mkdir_p(directory(config)) do
      :ok -> :ok
      {:error, reason} -> {:error, {:transcript_store_directory_error, reason}}
    end
  end

  # JSONL keeps append semantics simple: each new transcript item is encoded as
  # one JSON document followed by a newline.
  defp append_line(path, encoded_message) do
    case File.write(path, encoded_message <> "\n", [:append]) do
      :ok -> :ok
      {:error, reason} -> {:error, {:transcript_store_write_failed, reason}}
    end
  end

  # Missing transcript files map to an empty transcript so the first read after
  # session creation behaves naturally.
  defp read_lines(path) do
    case File.read(path) do
      {:ok, contents} ->
        contents
        |> String.split("\n", trim: true)
        |> then(&{:ok, &1})

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, {:transcript_store_read_failed, reason}}
    end
  end

  # Each stored line becomes one typed transcript struct again. The reducer
  # stops at the first decode error to avoid mixing valid and invalid history.
  defp decode_lines(lines) do
    Enum.reduce_while(lines, {:ok, []}, fn line, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          case decode_message(decoded) do
            {:ok, message} -> {:cont, {:ok, [message | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, error} ->
          {:halt, {:error, {:invalid_transcript_store_json, Exception.message(error)}}}
      end
    end)
    |> case do
      {:ok, messages} -> {:ok, Enum.reverse(messages)}
      error -> error
    end
  end

  # Transcript messages are stored with a `type` tag so the typed Elixir
  # variants can be reconstructed when reading the JSONL file back.
  defp encode_message(%Message.Transcript.User{} = message) do
    {:ok,
     %{
       "type" => "user",
       "id" => message.id,
       "session_id" => message.session_id,
       "content" => message.content,
       "inserted_at" => encode_datetime(message.inserted_at)
     }}
  end

  defp encode_message(%Message.Transcript.Assistant{} = message) do
    {:ok,
     %{
       "type" => "assistant",
       "id" => message.id,
       "session_id" => message.session_id,
       "content" => message.content,
       "inserted_at" => encode_datetime(message.inserted_at)
     }}
  end

  defp encode_message(%Message.Transcript.AssistantToolCall{} = message) do
    {:ok,
     %{
       "type" => "assistant_tool_call",
       "id" => message.id,
       "session_id" => message.session_id,
       "tool_calls" => message.tool_calls,
       "inserted_at" => encode_datetime(message.inserted_at)
     }}
  end

  defp encode_message(%Message.Transcript.Tool{} = message) do
    {:ok,
     %{
       "type" => "tool",
       "id" => message.id,
       "session_id" => message.session_id,
       "tool_call_id" => message.tool_call_id,
       "name" => message.name,
       "content" => message.content,
       "inserted_at" => encode_datetime(message.inserted_at)
     }}
  end

  defp decode_message(%{
         "type" => "user",
         "id" => id,
         "session_id" => session_id,
         "content" => content,
         "inserted_at" => inserted_at
       }) do
    with {:ok, inserted_at} <- decode_datetime(inserted_at) do
      {:ok,
       %Message.Transcript.User{
         id: id,
         session_id: session_id,
         content: content,
         inserted_at: inserted_at
       }}
    end
  end

  defp decode_message(%{
         "type" => "assistant",
         "id" => id,
         "session_id" => session_id,
         "content" => content,
         "inserted_at" => inserted_at
       }) do
    with {:ok, inserted_at} <- decode_datetime(inserted_at) do
      {:ok,
       %Message.Transcript.Assistant{
         id: id,
         session_id: session_id,
         content: content,
         inserted_at: inserted_at
       }}
    end
  end

  defp decode_message(%{
         "type" => "assistant_tool_call",
         "id" => id,
         "session_id" => session_id,
         "tool_calls" => tool_calls,
         "inserted_at" => inserted_at
       })
       when is_list(tool_calls) do
    with {:ok, inserted_at} <- decode_datetime(inserted_at) do
      {:ok,
       %Message.Transcript.AssistantToolCall{
         id: id,
         session_id: session_id,
         tool_calls: tool_calls,
         inserted_at: inserted_at
       }}
    end
  end

  defp decode_message(%{
         "type" => "tool",
         "id" => id,
         "session_id" => session_id,
         "tool_call_id" => tool_call_id,
         "name" => name,
         "content" => content,
         "inserted_at" => inserted_at
       }) do
    with {:ok, inserted_at} <- decode_datetime(inserted_at) do
      {:ok,
       %Message.Transcript.Tool{
         id: id,
         session_id: session_id,
         tool_call_id: tool_call_id,
         name: name,
         content: content,
         inserted_at: inserted_at
       }}
    end
  end

  defp decode_message(other) do
    {:error, {:invalid_transcript_store_payload, other}}
  end

  # Timestamps are stored as ISO8601 strings so the transcript files remain
  # readable and easy to inspect outside Elixir.
  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp decode_datetime(nil), do: {:ok, nil}

  defp decode_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, reason} -> {:error, {:invalid_transcript_store_datetime, reason}}
    end
  end

  defp decode_datetime(other), do: {:error, {:invalid_transcript_store_datetime, other}}

  defp transcript_path(session_id, config) do
    Path.join(directory(config), "#{session_id}.jsonl")
  end

  # JSON config may use string keys, while tests often use atom keys, so the
  # adapter accepts both representations transparently.
  defp directory(config) do
    Map.get(config, :directory, Map.get(config, "directory", @default_directory))
  end
end
