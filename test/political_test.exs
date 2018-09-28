defmodule PoliticalTest do
  use ExUnit.Case
  doctest Political

  test "greets the world" do
    assert Political.hello() == :world
  end
end
