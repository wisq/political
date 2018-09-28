defmodule Political.Stats do
  # All keywords are case-insensitive.
  # Strings will be searched as-is (special characters escaped).
  # Regexes will be matched directly.
  @keywords [
    trump: [
      "trump",
      # Party names (singular or plural):
      "republican",
      "republicans",
      "democrat",
      "democrats",
      "gop",
      # Spokespersons:
      "kellyanne",
      "huckabee",
      "sanders",
      "spicer",
      "scaramucci",
      "the mooch",
      # Lawyers / criminals:
      "manafort",
      "cohen",
      "giuliani",
      "avenatti",
      # Targets:
      "mueller",
      "comey",
      # (as in Stormy)
      "daniels",
      # Appointees:
      "kavanaugh",
      "sessions",
      # Other republicans:
      "mccain",
      "paul ryan"
    ],
    brexit: [
      "brexit",
      # Party names (singular or plural):
      "tory",
      "tories",
      "ukip",
      "dup",
      # People:
      "theresa",
      "corbyn",
      "boris",
      "barnier",
      # Concepts:
      "article 50",
      "customs union",
      "hard exit",
      "soft exit"
    ]
  ]

  @topics Keyword.keys(@keywords) ++ [:other]

  @regexes Enum.map(@keywords, fn {key, terms} ->
             terms =
               Enum.map(terms, fn
                 str when is_binary(str) -> Regex.escape(str)
                 %Regex{} = rx -> Regex.source(rx)
               end)

             {key, ~r{\b(#{Enum.join(terms, "|")})\b}i}
           end)

  def regexes, do: @regexes

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
      total: %Counts{},
      topics: %{}
    )

    def key(dt, :weekly) do
      dt
      |> Timex.Timezone.convert("Etc/UTC")
      |> Timex.beginning_of_week()
      |> Timex.format!("{YYYY}-{0M}-{0D}")
    end

    def key(dt, :monthly) do
      dt
      |> Timex.Timezone.convert("Etc/UTC")
      |> Timex.format!("{YYYY}-{0M}")
    end

    def get(bucket, key) do
      Map.get(bucket.topics, key)
    end

    def add(bucket, msg, cats) do
      c = Counts.count(msg)
      topics = Enum.reduce(cats, bucket.topics, &apply_category(&1, &2, c))

      %Bucket{bucket | topics: topics, total: Counts.add(bucket.total, c)}
    end

    defp apply_category(categ, bucket, c) do
      Map.update(bucket, categ, c, &Counts.add(&1, c))
    end
  end

  def topics, do: @topics

  def stream(messages_stream, interval) do
    messages_stream
    |> Stream.map(fn msg ->
      {msg, message_categories(msg)}
    end)
    |> Stream.concat([:done])
    |> Stream.transform(nil, &transform_bucket(&1, &2, interval))
  end

  def message_categories(msg) do
    [
      msg.text,
      Enum.map(msg.embeds, & &1.title),
      Enum.map(msg.embeds, & &1.description)
    ]
    |> List.flatten()
    |> Enum.flat_map(&text_categories/1)
    |> Enum.uniq()
    |> default_to_other()
  end

  defp text_categories(nil), do: []

  defp text_categories(str) do
    @regexes
    |> Enum.filter(fn {_key, rx} -> str =~ rx end)
    |> Enum.map(fn {key, _rx} -> key end)
  end

  defp default_to_other([]), do: [:other]
  defp default_to_other(cats), do: cats

  defp transform_bucket(:done, bucket, _mode), do: {[bucket], nil}

  defp transform_bucket({msg, cats}, bucket, interval) do
    key = Bucket.key(msg.timestamp, interval)

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
