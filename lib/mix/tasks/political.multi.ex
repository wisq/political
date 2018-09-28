defmodule Mix.Tasks.Political.Multi do
  use Mix.Task

  @shortdoc "Show messages that span multiple topics"

  def run([file]) do
    Mix.Task.run("app.start")

    count =
      Political.Parser.parse_file(file)
      |> Stream.map(fn msg ->
        {msg, Political.Stats.message_categories(msg)}
      end)
      |> Stream.filter(fn
        {_m, [_c]} -> false
        {_m, [_c | _cs]} -> true
      end)
      |> Stream.map(fn {msg, _cats} -> "#{msg.author}: #{msg.text}\n\n" end)
      |> Stream.into(IO.stream(:stdio, :line))
      |> Enum.count()

    IO.puts("\n\nTotal multi-topic messages: #{count}")
  end

  def run(_) do
    Mix.raise("Usage: mix political.multi <HTML file>")
  end
end
