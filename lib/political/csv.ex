defmodule Political.CSV do
  alias Political.Stats
  alias Political.Stats.Bucket

  def stream(stats_stream) do
    Stream.concat([:header], stats_stream)
    |> Stream.map(&generate_row/1)
    |> NimbleCSV.RFC4180.dump_to_stream()
  end

  defp generate_row(:header) do
    ["Bucket" | header_columns()]
  end

  defp generate_row(bucket) do
    [bucket.key | bucket_columns(bucket)]
  end

  defp header_columns() do
    topics =
      Stats.topics()
      |> Enum.map(&"\"#{&1}\"")

    ["Total" | topics]
    |> Enum.flat_map(fn type ->
      [
        "#{type} messages",
        "#{type} links"
      ]
    end)
  end

  defp bucket_columns(bucket) do
    [:total | Stats.topics()]
    |> Enum.flat_map(&bucket_columns(bucket, &1))
  end

  defp bucket_columns(bucket, :total) do
    bucket.total
    |> counts_columns()
  end

  defp bucket_columns(bucket, topic) do
    bucket
    |> Bucket.get(topic)
    |> counts_columns()
  end

  defp counts_columns(nil), do: ["", ""]
  defp counts_columns(c), do: [c.messages, c.embeds]
end
