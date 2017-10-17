defmodule CloudWatch do
  @behaviour :gen_event
  @default_endpoint "amazonaws.com"
  @default_format "$metadata[$level] $message\n"
  @default_level :info
  @default_max_buffer_size 10_485

  alias CloudWatch.InputLogEvent

  def init(_) do
    {:ok, configure(Application.get_env(:logger, CloudWatch, []))}
  end

  def handle_call({:configure, opts}, _) do
    {:ok, :ok, configure(opts)}
  end

  def handle_call(_, state) do
    {:ok, :ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    case Logger.compare_levels(level, state.level) do
      :lt -> {:ok, state}
      _ ->
        %{buffer: buffer, buffer_size: buffer_size} = state
        message = state.format
        |> Logger.Formatter.format(level, msg, ts, md)
        |> IO.chardata_to_string
        buffer = List.insert_at(buffer, -1, %InputLogEvent{message: message, timestamp: ts})
        state
        |> Map.merge(%{buffer: buffer, buffer_size: buffer_size + byte_size(message) + 26})
        |> flush()
    end
  end

  def handle_event(:flush, state) do
    {:ok, Map.merge(state, %{buffer: [], buffer_size: 0})}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_previous_version_number, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp configure(opts) do
    opts = Keyword.merge(Application.get_env(:logger, CloudWatch, []), opts)
    access_key_id = Keyword.get(opts, :access_key_id)
    endpoint = Keyword.get(opts, :endpoint, @default_endpoint)
    format = Logger.Formatter.compile(Keyword.get(opts, :format, @default_format))
    level = Keyword.get(opts, :level, @default_level)
    log_group_name = Keyword.get(opts, :log_group_name)
    log_stream_name = Keyword.get(opts, :log_stream_name)
    max_buffer_size = Keyword.get(opts, :max_buffer_size, @default_max_buffer_size)
    region = Keyword.get(opts, :region)
    secret_access_key = Keyword.get(opts, :secret_access_key)
    client = %AWS.Client{access_key_id: access_key_id, secret_access_key: secret_access_key, region: region, endpoint: endpoint}
    %{buffer: [], buffer_size: 0, client: client, format: format, level: level, log_group_name: log_group_name, log_stream_name: log_stream_name, max_buffer_size: max_buffer_size, sequence_token: nil}
  end

  defp flush(%{buffer: buffer, buffer_size: buffer_size, max_buffer_size: max_buffer_size} = state) when buffer_size < max_buffer_size and length(buffer) < 10_000 do
    {:ok, state}
  end

  defp flush(state) do
    case AWS.Logs.put_log_events(state.client, %{logEvents: Enum.sort_by(state.buffer, &(&1.timestamp)),
      logGroupName: state.log_group_name, logStreamName: state.log_stream_name, sequenceToken: state.sequence_token}) do
        {:ok, %{"nextSequenceToken" => next_sequence_token}, _} ->
          {:ok, Map.merge(state, %{buffer: [], buffer_size: 0, sequence_token: next_sequence_token})}
        {:error, {"DataAlreadyAcceptedException", "The given batch of log events has already been accepted. The next batch can be sent with sequenceToken: " <> next_sequence_token}} ->
          state
          |> Map.put(:sequence_token, next_sequence_token)
          |> flush()
        {:error, {"InvalidSequenceTokenException", "The given sequenceToken is invalid. The next expected sequenceToken is: " <> next_sequence_token}} ->
          state
          |> Map.put(:sequence_token, next_sequence_token)
          |> flush()
        {:error, {"ResourceNotFoundException", "The specified log group does not exist."}} ->
          AWS.Logs.create_log_group(state.client, %{logGroupName: state.log_group_name})
          AWS.Logs.create_log_stream(state.client, %{logGroupName: state.log_group_name, logStreamName: state.log_stream_name})
          flush(state)
        {:error, {"ResourceNotFoundException", "The specified log stream does not exist."}} ->
          AWS.Logs.create_log_stream(state.client, %{logGroupName: state.log_group_name, logStreamName: state.log_stream_name})
          flush(state)
        {:error, %HTTPoison.Error{id: nil, reason: :closed}} ->
          state
          |> flush()
    end
  end
end
