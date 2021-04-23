defmodule CloudWatch.Utils do
  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  def convert_timestamp({{years, months, days}, {hours, minutes, seconds, milliseconds}} = _timestamp) do
    :calendar.datetime_to_gregorian_seconds({{years, months, days}, {hours, minutes, seconds}})
    |> Kernel.-(@epoch)
    |> Kernel.*(1000)
    |> Kernel.+(milliseconds)
  end
end
