defmodule HoneylixirEventTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.Event

  test "create/0" do
    event = Honeylixir.Event.create()

    assert event.api_host == "https://api.honeycomb.io"
    assert event.sample_rate == 1
    assert event.team_writekey == nil
    assert event.dataset == nil
    assert event.timestamp =~ ~r(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)
    assert event.fields == %{"service_name" => "honeylixir-tests"}

    old_val = Application.get_env(:honeylixir, :service_name)

    Application.put_env(:honeylixir, :service_name, nil)

    event = Honeylixir.Event.create()
    refute Map.has_key?(event.fields, "service_name")

    Application.put_env(:honeylixir, :service_name, old_val)

    Honeylixir.GlobalFields.add_field("global", "this is great")

    event = Honeylixir.Event.create()
    assert event.fields == %{"global" => "this is great", "service_name" => "honeylixir-tests"}

    Honeylixir.GlobalFields.remove_field("global")
  end

  test "create/1 - timestamp" do
    timestamp = "2020-09-24T04:45:07.753385Z"

    event = Honeylixir.Event.create(timestamp)

    assert event.timestamp == timestamp
  end

  test "create/1 - fields" do
    fields = %{"field1" => "some_value", "field2" => "othervalue", "service_name" => "override"}

    event = Honeylixir.Event.create(fields)

    assert event.fields["field1"] == "some_value"
    assert event.fields["field2"] == "othervalue"
    assert event.fields["service_name"] == "override"
  end

  test "create/2" do
    timestamp = "2020-09-24 04:45:07.753385Z"
    fields = %{"field1" => "some_value", "field2" => "othervalue", "service_name" => "override"}

    event = Honeylixir.Event.create(timestamp, fields)

    assert event.timestamp == timestamp
    assert event.fields["field1"] == "some_value"
    assert event.fields["field2"] == "othervalue"
    assert event.fields["service_name"] == "override"
  end

  test "add_field/3" do
    event =
      Honeylixir.Event.create()
      |> Honeylixir.Event.add_field("something", "new")

    assert event.fields["something"] == "new"
  end

  test "add/2" do
    event =
      Honeylixir.Event.create()
      |> Honeylixir.Event.add(%{"foobar" => "amazing"})

    assert event.fields["foobar"] == "amazing"
  end

  test "send/1" do
    event = Honeylixir.Event.create()

    # Default sample rate of 1
    assert Honeylixir.Event.send(event) == :ok

    :rand.seed(:exsss, {123, 456, 789})
    event = %{event | sample_rate: 2, metadata: %{id: "test-send/1"}}

    # The ordering here is important and relies on the seed setting above
    #
    # random/1 returns 2
    :telemetry.attach(
      "event_test.send/1",
      [:honeylixir, :event, :send],
      fn _, _, %{response: response}, _ ->
        if response.metadata == %{id: "test-send/1"} do
          assert response.err == :sampled
        end
      end,
      nil
    )

    assert Honeylixir.Event.send(event) == :ok

    :telemetry.detach("event_test.send/1")

    # random/1 returns 1
    assert Honeylixir.Event.send(Honeylixir.Event.create()) == :ok
  end
end
