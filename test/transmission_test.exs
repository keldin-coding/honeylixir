defmodule HoneylixirTransmissionTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.Transmission

  test "send_event/1" do
    # Try to ensure things are clean
    Honeylixir.FakeClient.clear()

    event = Honeylixir.Event.create()

    # Default sample rate of 1
    assert Honeylixir.Transmission.send_event(event) == {:ok, :processed}

    :rand.seed(:exsss, {123, 456, 789})
    event_with_rate_2 = %{event | sample_rate: 2}

    # The ordering here is important and relies on the seed setting above
    # random/1 returns 2
    assert Honeylixir.Transmission.send_event(event_with_rate_2) == {:ok, :sampled}
    # random/1 returns 1
    assert Honeylixir.Transmission.send_event(event) == {:ok, :processed}
  end
end
