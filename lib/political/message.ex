defmodule Political.Message do
  @enforce_keys [:author, :timestamp, :text]
  defstruct(
    author: nil,
    timestamp: nil,
    text: nil,
    embeds: []
  )
end
