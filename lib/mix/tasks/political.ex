defmodule Mix.Tasks.Political do
  use Mix.Task

  @shortdoc "Parse a chat log and produce statistics"

  def run([file]), do: process(file, :weekly)
  def run([file, "weekly"]), do: process(file, :weekly)
  def run([file, "monthly"]), do: process(file, :monthly)

  def run(_) do
    Mix.raise("Usage: mix political <HTML file> [weekly|monthly]")
  end

  defp process(file, interval) do
    Mix.Task.run("app.start")

    Political.Parser.parse_file(file)
    |> Political.Stats.stream(interval)
    |> Political.CSV.stream()
    |> Stream.into(IO.stream(:stdio, :line))
    |> Stream.run()
  end
end
