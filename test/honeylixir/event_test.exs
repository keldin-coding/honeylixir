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

  @tag :flaky
  test "send/1" do
    # Setup a sampler so we can guarantee sampling for tests, which is fair for
    # real life too
    sampler = fn rate, fields ->
      {Honeylixir.DeterminsticSampler.should_sample?(rate, fields["value"]), rate}
    end

    Application.put_env(:honeylixir, :sample_hook, sampler)

    # Start up an Agent that sits and accepts data for the responses to test against.
    {:ok, _pid} = start_supervised(HoneylixirTestListener)

    :telemetry.attach(
      "event_test.send/1",
      [:honeylixir, :event, :send],
      fn _, _, %{response: %Honeylixir.Response{metadata: metadata, err: err}}, _ ->
        HoneylixirTestListener.seen(metadata[:id], err)
      end,
      nil
    )

    # Default sample rate of 1
    event =
      Honeylixir.Event.create(%{"value" => "cool"})
      |> Honeylixir.Event.add_metadata(%{id: "not-sampled"})

    assert Honeylixir.Event.send(event) == :ok

    event = %{event | sample_rate: 2, metadata: %{id: "test-send/1"}}
    assert Honeylixir.Event.send(event) == :ok

    # Force them to send
    Honeylixir.TransmissionQueue.process_batch(Honeylixir.TransmissionQueue.queue_key(event))
    # Do I hate this? yes. Could I probably find a way to make this better? Also yes.
    # For now, though, this at least helps us actually test things flowing and
    # sample hooks and everything entailed. This is KIND of an integration test and
    # probably says something about the architecture here that event testing is so
    # entangled with so much asynchronous processing.
    :timer.sleep(1000)

    assert HoneylixirTestListener.values() == %{"not-sampled" => nil, "test-send/1" => :sampled}

    # Quick teardown
    :telemetry.detach("event_test.send/1")
    Application.delete_env(:honeylixir, :sample_hook)
  end
end
