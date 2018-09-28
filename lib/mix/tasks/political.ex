defmodule Mix.Tasks.Political do
  use Mix.Task

  @shortdoc "Parse a chat log and produce statistics"

  def run([file]) do
    Mix.Task.run("app.start")

    Political.Parser.parse_file(file)
    |> Political.Stats.collect()
    |> Political.CSV.output()
    |> IO.inspect()
  end

  def run(_) do
    Mix.raise("Usage: mix political <HTML file>")
  end
end
