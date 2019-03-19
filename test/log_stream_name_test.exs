defmodule LogStreamNameTest do
  @backend CloudWatch
  @stream_name_prefix "2018-01-01"
  @stream_name_postfix "test1234"

  alias CloudWatch.{Cycler, InputLogEvent}

  import Mock

  require Logger

  use ExUnit.Case, async: false

  setup_all do
    {:ok, _} = Cycler.start_link
    Logger.add_backend(@backend)
    :ok = Logger.configure_backend(@backend, [format: "$message", level: :info, log_group_name: "testLogGroup", log_stream_name: {LogStreamNameTest, :format_name, [@stream_name_prefix, @stream_name_postfix]}, max_buffer_size: 39])
  end

  setup do
    on_exit fn -> Logger.flush end
    :ok
  end

  test "creates a log stream when the log stream does not exist" do
    log_stream_name = format_name(@stream_name_prefix, @stream_name_postfix)
    with_mock AWS.Logs, [create_log_stream: fn (_, _) -> {:ok, nil, nil} end, put_log_events: fn (_, _) -> Cycler.next_response end] do
      Cycler.reset_responses([{:error, {"ResourceNotFoundException", "The specified log stream does not exist."}}, {:ok, %{"nextSequenceToken" => "57682394657383646473"}, nil}])
      Logger.error("ArithmeticError")
      :timer.sleep(100)
      assert called(AWS.Logs.create_log_stream(:_, %{logGroupName: "testLogGroup", logStreamName: log_stream_name}))
      assert called(AWS.Logs.put_log_events(:_, %{logEvents: [%InputLogEvent{message: "ArithmeticError", timestamp: :_}], logGroupName: "testLogGroup", logStreamName: log_stream_name, sequenceToken: :_}))
    end
  end

  test "creates a log group and a log stream when the log group does not exist" do
    log_stream_name = format_name(@stream_name_prefix, @stream_name_postfix)
    with_mock AWS.Logs, [create_log_group: fn (_, _) -> {:ok, nil, nil} end, create_log_stream: fn (_, _) -> {:ok, nil, nil} end, put_log_events: fn (_, _) -> Cycler.next_response end] do
      Cycler.reset_responses([{:error, {"ResourceNotFoundException", "The specified log group does not exist."}}, {:ok, %{"nextSequenceToken" => "5768239465"}, nil}])
      Logger.error("ArithmeticError")
      :timer.sleep(100)
      assert called(AWS.Logs.create_log_group(:_, %{logGroupName: "testLogGroup"}))
      assert called(AWS.Logs.create_log_stream(:_, %{logGroupName: "testLogGroup", logStreamName: log_stream_name}))
      assert called(AWS.Logs.put_log_events(:_, %{logEvents: [%InputLogEvent{message: "ArithmeticError", timestamp: :_}], logGroupName: "testLogGroup", logStreamName: log_stream_name, sequenceToken: :_}))
    end
  end

  # Calculate log stream name
  def format_name(prefix, postfix) do
    "#{prefix}_LOG_STREAM_NAME_#{postfix}"
  end

end
