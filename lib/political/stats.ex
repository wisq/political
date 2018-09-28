defmodule Political.Stats do
  alias Political.Stats

  @keywords [
    trump: [
      "trump",
      "republican",
      "kellyanne",
      "manafort",
      "mueller",
      "giuliani",
      "cohen",
      "kavanaugh"
    ],
    brexit: ["brexit", "theresa", "ukip", "article 50", "customs union"]
  ]

  defmodule Counts do
    defstruct(
      messages: 0,
      embeds: 0
    )

    def count(msg) do
      %Counts{messages: 1, embeds: Enum.count(msg.embeds)}
    end

    def add(c1, c2) do
      %Counts{
        messages: c1.messages + c2.messages,
        embeds: c1.embeds + c2.embeds
      }
    end
  end

  defmodule Bucket do
    def key(dt) do
      dt
      |> Timex.beginning_of_week()
      |> Timex.format!("{YYYY}-{0M}-{0D}")
    end

    def update(old, msg, cats) do
      counts = Counts.count(msg)
      new = Enum.reduce(cats, old || %{}, &apply_category(&1, &2, counts))
      {old, new}
    end

    defp apply_category(categ, bucket, counts) do
      Map.update(bucket, categ, counts, &Counts.add(&1, counts))
    end
  end

  @enforce_keys [:keywords]
  defstruct(
    keywords: [],
    buckets: %{}
  )

  @regexes Enum.map(@keywords, fn {key, words} ->
             {key, ~r{(^|\W)#{Enum.join(words, "|")}(\W|$)}}
           end)

  def new do
    %Stats{keywords: Keyword.keys(@keywords)}
  end

  def collect(stream) do
    stream
    |> Stream.map(fn msg ->
      {msg, message_categories(msg)}
    end)
    |> Enum.take(5000)
    |> Enum.reduce(new(), &add_to_bucket/2)
  end

  defp message_categories(msg) do
    [
      msg.text,
      Enum.map(msg.embeds, & &1.title),
      Enum.map(msg.embeds, & &1.description)
    ]
    |> List.flatten()
    |> Enum.flat_map(&text_categories/1)
    |> Enum.uniq()
  end

  defp text_categories(nil), do: []

  defp text_categories(str) do
    @regexes
    |> Enum.filter(fn {_key, rx} -> str =~ rx end)
    |> Enum.map(fn {key, _rx} -> key end)
  end

  defp add_to_bucket({m, cats}, %Stats{} = stats) do
    {_, buckets} =
      Map.get_and_update(
        stats.buckets,
        Bucket.key(m.timestamp),
        &Bucket.update(&1, m, cats)
      )

    %Stats{stats | buckets: buckets}
  end
end
