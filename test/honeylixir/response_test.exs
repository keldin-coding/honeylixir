defmodule HoneylixirResponseTest do
  use ExUnit.Case, async: true
  doctest Honeylixir.Response

  test "struct" do
    resp = %Honeylixir.Response{
      metadata: %{},
      duration: 100,
      status_code: 202,
      body: "",
      err: nil
    }

    assert resp == %Honeylixir.Response{
             metadata: %{},
             duration: 100,
             status_code: 202,
             body: "",
             err: nil
           }
  end
end
