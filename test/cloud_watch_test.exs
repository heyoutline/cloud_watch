defmodule CloudWatchTest do
  @backend CloudWatch

  alias CloudWatch.Cycler

  import Mock

  require Logger

  use ExUnit.Case, async: false

  setup_all do
    start_supervised(Cycler)
    Logger.add_backend(@backend)

    :ok =
      Logger.configure_backend(@backend,
        format: "$message",
        level: :info,
        log_group_name: "testLogGroup",
        log_stream_name: "testLogStream",
        max_buffer_size: 39
      )

    log_module =
      if Code.ensure_loaded?(AWS.Logs) do
        # until AWS 0.6.0
        AWS.Logs
      else
        AWS.CloudWatchLogs
      end

    %{aws_log_module: log_module}
  end

  setup do
    on_exit(fn -> Logger.flush() end)
    :ok
  end

  test "creates a log stream when the log stream does not exist", %{aws_log_module: log_module} = _context do
    with_mock log_module,
      create_log_stream: fn _, _ -> {:ok, nil, nil} end,
      put_log_events: fn _, _ -> Cycler.next_response() end do
      Cycler.reset_responses([
        {:error, {"ResourceNotFoundException", "The specified log stream does not exist."}},
        {:ok, %{"nextSequenceToken" => "57682394657383646473"}, nil}
      ])

      Logger.error("ArithmeticError")
      :timer.sleep(100)

      assert called(
               log_module.create_log_stream(:_, %{
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream"
               })
             )

      assert called(
               log_module.put_log_events(:_, %{
                 logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream",
                 sequenceToken: :_
               })
             )
    end
  end

  test "creates a log group and a log stream when the log group does not exist", %{aws_log_module: log_module} do
    with_mock log_module,
      create_log_group: fn _, _ -> {:ok, nil, nil} end,
      create_log_stream: fn _, _ -> {:ok, nil, nil} end,
      put_log_events: fn _, _ -> Cycler.next_response() end do
      Cycler.reset_responses([
        {:error, {"ResourceNotFoundException", "The specified log group does not exist."}},
        {:ok, %{"nextSequenceToken" => "5768239465"}, nil}
      ])

      Logger.error("ArithmeticError")
      :timer.sleep(100)
      assert called(log_module.create_log_group(:_, %{logGroupName: "testLogGroup"}))

      assert called(
               log_module.create_log_stream(:_, %{
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream"
               })
             )

      assert called(
               log_module.put_log_events(:_, %{
                 logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream",
                 sequenceToken: :_
               })
             )
    end
  end

  test "does not put log events that do not meet the log level", %{aws_log_module: log_module} do
    with_mock log_module,
      put_log_events: fn _, _ -> {:ok, %{"nextSequenceToken" => "5768239465"}, nil} end do
      Logger.debug("ArithmeticError")
      :timer.sleep(100)
      refute called(log_module.put_log_events(:_, :_))
    end
  end

  test "does not put log events when the buffer size is less than the configured maximum buffer size", %{
    aws_log_module: log_module
  } do
    with_mock log_module,
      put_log_events: fn _, _ -> {:ok, %{"nextSequenceToken" => "5768239465"}, nil} end do
      Logger.error("RuntimeError")
      :timer.sleep(100)
      refute called(log_module.put_log_events(:_, :_))
    end
  end

  test "puts log events that meet the log level", %{aws_log_module: log_module} do
    with_mock log_module,
      put_log_events: fn _, _ -> {:ok, %{"nextSequenceToken" => "5768239465"}, nil} end do
      Logger.info("ArgumentError")
      :timer.sleep(100)

      assert called(
               log_module.put_log_events(:_, %{
                 logEvents: [%{message: "ArgumentError", timestamp: :_}],
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream",
                 sequenceToken: :_
               })
             )
    end
  end

  test "puts log events when the buffer size is greater then the configured maximum buffer size", %{
    aws_log_module: log_module
  } do
    with_mock log_module,
      put_log_events: fn _, _ -> {:ok, %{"nextSequenceToken" => "5768239465"}, nil} end do
      Logger.error("ArithmeticError")
      :timer.sleep(100)

      assert called(
               log_module.put_log_events(:_, %{
                 logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream",
                 sequenceToken: :_
               })
             )
    end
  end

  test "puts log events with the next sequence token when the data has already been accepted", %{
    aws_log_module: log_module
  } do
    with_mock log_module, put_log_events: fn _, _ -> Cycler.next_response() end do
      Cycler.reset_responses([
        {:error,
         {"DataAlreadyAcceptedException",
          "The given batch of log events has already been accepted. The next batch can be sent with sequenceToken: 5768239465"}},
        {:ok, %{"nextSequenceToken" => "3857374635"}, nil}
      ])

      Logger.error("ArithmeticError")
      :timer.sleep(100)

      assert called(
               log_module.put_log_events(:_, %{
                 logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                 logGroupName: "testLogGroup",
                 logStreamName: "testLogStream",
                 sequenceToken: "5768239465"
               })
             )
    end
  end

  describe "puts log events with the next sequence token when the sequence token was invalid" do
    test "with aws and ex_aws pre 2.2.4", %{aws_log_module: log_module} do
      with_mock log_module, put_log_events: fn _, _ -> Cycler.next_response() end do
        Cycler.reset_responses([
          {:error,
           {"InvalidSequenceTokenException",
            "The given sequenceToken is invalid. The next expected sequenceToken is: 5768239463"}},
          {:ok, %{"nextSequenceToken" => "3857354916"}, nil}
        ])

        Logger.error("ArithmeticError")
        :timer.sleep(100)

        assert called(
                 log_module.put_log_events(:_, %{
                   logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                   logGroupName: "testLogGroup",
                   logStreamName: "testLogStream",
                   sequenceToken: "5768239463"
                 })
               )
      end
    end

    test "with ex_aws after 2.2.4 when it returns next sequence token as third element in error reason tuple", %{
      aws_log_module: log_module
    } do
      with_mock log_module, put_log_events: fn _, _ -> Cycler.next_response() end do
        Cycler.reset_responses([
          {:error,
           {"InvalidSequenceTokenException",
            "The given sequenceToken is invalid. The next expected sequenceToken is: 5768239463", "5768239463"}},
          {:ok, %{"nextSequenceToken" => "3857354916"}, nil}
        ])

        Logger.error("ArithmeticError")
        :timer.sleep(100)

        assert called(
                 log_module.put_log_events(:_, %{
                   logEvents: [%{message: "ArithmeticError", timestamp: :_}],
                   logGroupName: "testLogGroup",
                   logStreamName: "testLogStream",
                   sequenceToken: "5768239463"
                 })
               )
      end
    end
  end
end
