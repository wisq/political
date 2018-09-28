defmodule Political.CSV do
  alias Political.Stats
  alias Political.Stats.Bucket

  def stream(stats_stream) do
    stats_stream
    |> Stream.transform(:header, &data_row/2)
    |> NimbleCSV.RFC4180.dump_to_stream()
  end

  defp data_row(row, :header) do
    {[header_row(), bucket_row(row)], :data}
  end

  defp data_row(row, :data) do
    {[bucket_row(row)], :data}
  end

  defp header_row() do
    ["Bucket" | header_columns()]
  end

  defp header_columns() do
    Stats.keywords()
    |> Enum.flat_map(fn keyword ->
      [
        "\"#{keyword}\" messages",
        "\"#{keyword}\" links"
      ]
    end)
  end

  defp bucket_row(bucket) do
    [bucket.key | bucket_columns(bucket)]
  end

  defp bucket_columns(bucket) do
    Stats.keywords()
    |> Enum.flat_map(fn keyword ->
      bucket
      |> Bucket.get(keyword)
      |> counts_columns()
    end)
  end

  defp counts_columns(nil), do: ["", ""]
  defp counts_columns(c), do: [c.messages, c.embeds]
end
