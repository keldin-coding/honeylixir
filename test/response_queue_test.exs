defmodule HoneylixirResponseQueueTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.ResponseQueue

  test "supports adding and getting responses in FIFO order" do
    start_supervised!(%{
      id: :test_r_queue,
      start:
        {Honeylixir.ResponseQueue, :start_link,
         [%{max_response_queue_size: 1}, [name: :test_r_queue]]}
    })

    # First one makes it in, second one doesn't. Both return :ok
    assert Honeylixir.ResponseQueue.add(canned_response(%{"b" => "b"}), :test_r_queue) == :ok
    assert Honeylixir.ResponseQueue.add(canned_response(%{"c" => "c"}), :test_r_queue) == :ok

    assert %Honeylixir.Response{
             metadata: %{"b" => "b"},
             duration: 100,
             status_code: 202,
             body: "",
             err: nil
           } == Honeylixir.ResponseQueue.pop(:test_r_queue)

    assert nil == Honeylixir.ResponseQueue.pop(:test_r_queue)
  end

  test "do_update/2" do
    initial_state = %{max_size: 1, size: 0, responses: :queue.new()}

    # Add something to it
    new_state = Honeylixir.ResponseQueue.do_update(initial_state, canned_response(%{"a" => "a"}))
    assert match?(%{max_size: 1, size: 1, responses: _}, new_state)

    %{responses: queue} = new_state
    {{:value, resp}, _} = :queue.out(queue)

    assert %Honeylixir.Response{
             metadata: %{"a" => "a"},
             duration: 100,
             status_code: 202,
             body: "",
             err: nil
           } == resp

    # Attempt another add, should fail and result in the same state given back
    second_state = Honeylixir.ResponseQueue.do_update(new_state, canned_response(%{"b" => "b"}))
    assert match?(%{max_size: 1, size: 1, responses: _}, second_state)

    %{responses: queue} = second_state
    {{:value, resp}, _} = :queue.out(queue)

    assert %Honeylixir.Response{
             metadata: %{"a" => "a"},
             duration: 100,
             status_code: 202,
             body: "",
             err: nil
           } == resp
  end

  test "do_pop/1" do
    initial_state = %{max_size: 1, size: 0, responses: :queue.new()}

    # Empty is empty
    assert Honeylixir.ResponseQueue.do_pop(initial_state) == {nil, initial_state}

    # Add an item
    new_state = Honeylixir.ResponseQueue.do_update(initial_state, canned_response(%{"a" => "a"}))

    # Popping gets it
    {resp, second_state} = Honeylixir.ResponseQueue.do_pop(new_state)

    assert %Honeylixir.Response{
             metadata: %{"a" => "a"},
             duration: 100,
             status_code: 202,
             body: "",
             err: nil
           } == resp

    assert second_state[:size] == 0
    assert :queue.len(second_state[:responses]) == 0
  end

  defp canned_response(metadata) do
    %Honeylixir.Response{
      metadata: metadata,
      duration: 100,
      status_code: 202,
      body: "",
      err: nil
    }
  end
end
