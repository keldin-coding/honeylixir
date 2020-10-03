defmodule HoneylixirTransmissionQueueTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.TransmissionQueue

  test "handle_call/3 - :get_all_queue_keys" do
    state = %{
      :batch_timing => 3,
      :max_queue_size => 4,
      :batch_size => 3,
      {"http://host", "abc", "data"} => %Honeylixir.TransmissionQueue{size: 0, items: []},
      {"http://host", "abc", "data2"} => %Honeylixir.TransmissionQueue{size: 0, items: []}
    }

    assert {:reply, [{"http://host", "abc", "data"}, {"http://host", "abc", "data2"}], state} ==
             Honeylixir.TransmissionQueue.handle_call(:get_all_queue_keys, nil, state)
  end

  test "handle_cast/3 - :enqueue_event" do
    state = %{
      :batch_timing => 3,
      :max_queue_size => 4,
      :batch_size => 2
    }

    {:noreply, new_state} =
      Honeylixir.TransmissionQueue.handle_cast({:enqueue_event, Honeylixir.Event.create()}, state)

    extracted_queue = Map.get(new_state, default_queue_key())
    assert extracted_queue.size == 1

    {{:value, event}, _} = :queue.out(extracted_queue.items)
    assert event == Honeylixir.Event.create()

    # Hit limit
    items =
      Enum.reduce(1..3, extracted_queue.items, fn _, acc ->
        :queue.in(Honeylixir.Event.create(), acc)
      end)

    new_queue = %Honeylixir.TransmissionQueue{size: 4, items: items}

    state = %{
      :batch_timing => 3,
      :max_queue_size => 4,
      :batch_size => 2,
      default_queue_key() => new_queue
    }

    assert {:noreply, state} ==
             Honeylixir.TransmissionQueue.handle_cast(
               {:enqueue_event, Honeylixir.Event.create()},
               state
             )

    resp = Honeylixir.ResponseQueue.pop()

    assert resp == %Honeylixir.Response{
             metadata: %{},
             duration: 0,
             status_code: nil,
             body: "",
             err: :overflow
           }
  end

  test "handle_cast/3 - :process_batch" do
    state = %{
      :batch_timing => 3,
      :max_queue_size => 4,
      :batch_size => 2
    }

    assert {:noreply, state} ==
             Honeylixir.TransmissionQueue.handle_cast(
               {:process_batch, default_queue_key()},
               state
             )

    state =
      Map.put(
        state,
        default_queue_key(),
        %Honeylixir.TransmissionQueue{
          size: 4,
          items: :queue.from_list(Enum.map(1..4, fn _ -> Honeylixir.Event.create() end))
        }
      )

    {:noreply, new_state} =
      Honeylixir.TransmissionQueue.handle_cast({:process_batch, default_queue_key()}, state)

    assert new_state[default_queue_key()].size == 2
    assert :queue.len(new_state[default_queue_key()].items) == 2
  end

  defp default_queue_key do
    {Application.get_env(:honeylixir, :api_host, "https://api.honeycomb.io"),
     Application.get_env(:honeylixir, :team_writekey), Application.get_env(:honeylixir, :dataset)}
  end
end
