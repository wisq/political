defmodule Political.Parser.Timestamp do
  def parse(str) do
    case Regex.run(~r{^(\d+)-([A-Z][a-z]+)-(\d+) (\d+):(\d+) ([AP]M)$}, str) do
      [^str, day, month, year, hour, minute, am_pm] ->
        %NaiveDateTime{
          year: String.to_integer("20#{year}"),
          month: month_to_number(month),
          day: String.to_integer(day),
          hour:
            case {String.to_integer(hour), am_pm} do
              {12, "AM"} -> 0
              {hh, "AM"} -> hh
              {12, "PM"} -> 12
              {hh, "PM"} -> 12 + hh
            end,
          minute: String.to_integer(minute),
          second: 0
        }
        |> guess_timezone()

      nil ->
        raise "Can't parse timestamp: #{inspect(str)}"
    end
  end

  defp month_to_number("Jan"), do: 1
  defp month_to_number("Feb"), do: 2
  defp month_to_number("Mar"), do: 3
  defp month_to_number("Apr"), do: 4
  defp month_to_number("May"), do: 5
  defp month_to_number("Jun"), do: 6
  defp month_to_number("Jul"), do: 7
  defp month_to_number("Aug"), do: 8
  defp month_to_number("Sep"), do: 9
  defp month_to_number("Oct"), do: 10
  defp month_to_number("Nov"), do: 11
  defp month_to_number("Dec"), do: 12

  defp guess_timezone(ndt) do
    tz =
      case Timex.Timezone.local(ndt) do
        %Timex.TimezoneInfo{} = tz -> tz
        %Timex.AmbiguousTimezoneInfo{after: tz} -> tz
      end

    fields =
      ndt
      |> Map.from_struct()
      |> Map.merge(%{
        time_zone: tz.full_name,
        zone_abbr: tz.abbreviation,
        utc_offset: tz.offset_utc,
        std_offset: tz.offset_std
      })

    struct!(DateTime, fields)
  end
end
