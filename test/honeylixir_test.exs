defmodule HoneylixirTest do
  use ExUnit.Case
  doctest Honeylixir

  test "greets the world" do
    assert Honeylixir.hello() == :world
  end
end
