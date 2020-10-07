defmodule CloudWatch.InputLogEventTest do
  alias CloudWatch.InputLogEvent

  use ExUnit.Case

  test "encodes message and timestamp" do
    input_log_event = %InputLogEvent{
      message: "ArgumentError",
      timestamp: {{2016, 10, 26}, {12, 8, 34, 220}}
    }

    encoded_input_log_event = Poison.Encoder.encode(input_log_event, %{})

    assert encoded_input_log_event == "{\"timestamp\":1477483714220,\"message\":\"ArgumentError\"}"
  end
end
