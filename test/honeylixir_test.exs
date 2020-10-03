defmodule HoneylixirTest do
  use ExUnit.Case, async: true
  doctest Honeylixir

  test "generate_long_id/0" do
    assert String.match?(Honeylixir.generate_long_id(), ~r/[a-f0-9]{32}/)
  end

  test "generate_short_id/0" do
    assert String.match?(Honeylixir.generate_short_id(), ~r/[a-f0-9]{16}/)
  end
end
