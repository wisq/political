defmodule Mix.Tasks.Political do
  use Mix.Task

  @shortdoc "Parse a chat log and produce statistics"

  def run([file]) do
    Mix.Task.run("app.start")

    Political.Parser.parse_file(file)
    |> Political.Stats.stream()
    |> Political.CSV.stream()
    |> Stream.into(IO.stream(:stdio, :line))
    |> Stream.run()
  end

  def run(_) do
    Mix.raise("Usage: mix political <HTML file>")
  end
end
