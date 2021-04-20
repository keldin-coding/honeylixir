defmodule HoneylixirGlobalFieldsTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.GlobalFields

  test "handles global fields" do
    Honeylixir.GlobalFields.add_field("new_key", "value")
    assert Honeylixir.GlobalFields.fields() == %{"new_key" => "value"}

    Honeylixir.GlobalFields.add_field("another", "foobar")
    assert Honeylixir.GlobalFields.fields() == %{"new_key" => "value", "another" => "foobar"}

    Honeylixir.GlobalFields.add_field("new_key", "replacement")

    assert Honeylixir.GlobalFields.fields() == %{
             "new_key" => "replacement",
             "another" => "foobar"
           }

    Honeylixir.GlobalFields.remove_field("new_key")
    assert Honeylixir.GlobalFields.fields() == %{"another" => "foobar"}

    Honeylixir.GlobalFields.remove_field("never_existed")
    assert Honeylixir.GlobalFields.fields() == %{"another" => "foobar"}

    Honeylixir.GlobalFields.remove_field("another")
  end
end
