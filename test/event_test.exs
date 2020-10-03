defmodule HoneylixirEventTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.Event

  test "create/0" do
    event = Honeylixir.Event.create()

    assert event.api_host == "https://api.honeycomb.io"
    assert event.sample_rate == 1
    assert event.team_writekey == nil
    assert event.dataset == nil
    assert event.timestamp == DateTime.to_string(DateTimeFake.utc_now())
    assert event.fields == %{"service_name" => "honeylixir-tests"}

    old_val = Application.get_env(:honeylixir, :service_name)

    Application.put_env(:honeylixir, :service_name, nil)

    event = Honeylixir.Event.create()
    refute Map.has_key?(event.fields, "service_name")

    Application.put_env(:honeylixir, :service_name, old_val)
  end

  test "create/1 - timestamp" do
    timestamp = "2020-09-24 04:45:07.753385Z"

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
    assert Honeylixir.ResponseQueue.pop() == nil

    :rand.seed(:exsss, {123, 456, 789})
    event = %{event | sample_rate: 2}

    # The ordering here is important and relies on the seed setting above
    #
    # TODO: These tests can eventually pull from the ResponseQueue once that is
    # a thing that exists.
    # random/1 returns 2
    assert Honeylixir.Event.send(event) == :ok
    resp = Honeylixir.ResponseQueue.pop()

    assert %Honeylixir.Response{
             metadata: %{},
             duration: 0,
             status_code: nil,
             body: nil,
             err: :sampled
           } == resp

    # random/1 returns 1
    assert Honeylixir.Event.send(event) == :ok
    assert Honeylixir.ResponseQueue.pop() == nil
  end
end
