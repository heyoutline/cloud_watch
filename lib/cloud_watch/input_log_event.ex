defmodule CloudWatch.InputLogEvent do
  @enforce_keys  [:message, :timestamp]

  defimpl Poison.Encoder do
    @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

    def encode(%{message: message, timestamp: timestamp}, options) do
      {{years, months, days}, {hours, minutes, seconds, milliseconds}} = timestamp
      timestamp = :calendar.datetime_to_gregorian_seconds({{years, months, days}, {hours, minutes, seconds}})
      |> Kernel.-(@epoch)
      |> Kernel.*(1000)
      |> Kernel.+(milliseconds)
      %{message: message, timestamp: timestamp}
      |> Poison.Encoder.encode(options)
      |> IO.chardata_to_string
    end
  end

  defstruct [:message, :timestamp]
end
