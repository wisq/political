defmodule Political.Stats do
  @keyword_lists [
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
    @enforce_keys [:key]
    defstruct(
      key: nil,
      counts: %{}
    )

    def key(dt) do
      dt
      |> Timex.Timezone.convert("Etc/UTC")
      |> Timex.beginning_of_week()
      |> Timex.format!("{YYYY}-{0M}-{0D}")
    end

    def get(bucket, key) do
      Map.get(bucket.counts, key)
    end

    def add(bucket, msg, cats) do
      c = Counts.count(msg)
      counts = Enum.reduce(cats, bucket.counts, &apply_category(&1, &2, c))
      %Bucket{bucket | counts: counts}
    end

    defp apply_category(categ, bucket, counts) do
      Map.update(bucket, categ, counts, &Counts.add(&1, counts))
    end
  end

  @keywords Keyword.keys(@keyword_lists)

  @regexes Enum.map(@keyword_lists, fn {key, words} ->
             {key, ~r{(^|\W)#{Enum.join(words, "|")}(\W|$)}}
           end)

  def keywords, do: @keywords

  def stream(messages_stream) do
    messages_stream
    |> Stream.map(fn msg ->
      {msg, message_categories(msg)}
    end)
    |> Stream.transform(nil, &transform_bucket/2)
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

  defp transform_bucket({msg, cats}, bucket) do
    key = Bucket.key(msg.timestamp)

    case bucket do
      nil ->
        bucket = %Bucket{key: key} |> Bucket.add(msg, cats)
        {[], bucket}

      %Bucket{key: ^key} ->
        bucket = Bucket.add(bucket, msg, cats)
        {[], bucket}

      %Bucket{key: old_key} = old ->
        unless old_key < key do
          raise "Message goes backwards in time: #{inspect(msg)}"
        end

        new = %Bucket{key: key} |> Bucket.add(msg, cats)
        {[old], new}
    end
  end
end
