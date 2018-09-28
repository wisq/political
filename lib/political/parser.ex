defmodule Political.Parser do
  import SweetXml
  alias Political.Parser.Timestamp
  alias Political.{Message, Embed}

  def parse_file(file) do
    File.open!(file, guess_mode(file))
    |> IO.stream(:line)
    |> stream_tags([:div])
    |> Stream.flat_map(&parse_div/1)
  end

  defp guess_mode(file) do
    if String.ends_with?(file, ".gz") do
      [:read, :compressed, :utf8]
    else
      [:read, :utf8]
    end
  end

  defp parse_div({:div, el}) do
    case xpath(el, ~x"./@class") do
      'chatlog__message-group' -> parse_message_group(el)
      _ -> []
    end
  end

  defp parse_message_group(el) do
    messages = xpath(el, ~x"./div[@class='chatlog__messages']")
    author = xpath(messages, ~x"./span[@class='chatlog__author-name']/@title"s)
    time = xpath(messages, ~x"./span[@class='chatlog__timestamp']/text()"s) |> Timestamp.parse()

    xpath(messages, ~x"./div"l)
    |> Enum.map(&parse_message_group_item(&1, author, time))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce([], &merge_embeds/2)
    |> Enum.reverse()
  end

  defp parse_message_group_item(item, author, time) do
    case xpath(item, ~x"./@class"s) do
      "chatlog__content" -> parse_message(item, author, time)
      "chatlog__embed" -> parse_embed(item)
      "chatlog__reactions" -> nil
      "chatlog__attachment" -> nil
    end
  end

  defp parse_message(msg, author, time) do
    %Message{
      author: author,
      timestamp: time,
      text: xpath(msg, ~x".//text()"sl) |> Enum.join(" ")
    }
  end

  defp parse_embed(embed) do
    attrs =
      [
        xpath(embed, ~x".//a[@class='chatlog__embed-title-link']")
        |> embed_title_link_attrs(),
        xpath(embed, ~x".//a[@class='chatlog__embed-author-name-link']")
        |> embed_author_link_attrs(),
        xpath(embed, ~x".//div[@class='chatlog__embed-description']")
        |> embed_description_attrs()
      ]
      |> Enum.reduce(&Map.merge/2)

    struct!(Embed, attrs)
  end

  defp embed_title_link_attrs(nil), do: %{}

  defp embed_title_link_attrs(link) do
    %{
      title: xpath(link, ~x"./text()"s),
      uri: xpath(link, ~x"./@href"s)
    }
  end

  defp embed_author_link_attrs(nil), do: %{}
  defp embed_author_link_attrs(link), do: %{author: xpath(link, ~x"./text()"s)}

  defp embed_description_attrs(nil), do: %{}
  defp embed_description_attrs(link), do: %{description: xpath(link, ~x"./text()"s)}

  defp merge_embeds(%Message{} = m, ms) do
    [m | ms]
  end

  defp merge_embeds(%Embed{} = e, [%Message{embeds: es} = m | ms]) do
    [%Message{m | embeds: es ++ [e]} | ms]
  end
end
