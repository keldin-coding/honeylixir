defmodule Honeylixir.ResponseQueue do
  @moduledoc """
  Available for tracking responses for each event sent via `Honeylixir.Transmission`.

  Currently does not block when the queue is full.
  """
  use Agent

  @doc false
  def start_link(%{max_response_queue_size: max_response_queue_size}, opts \\ []) do
    name = Access.get(opts, :name, __MODULE__)

    Agent.start_link(
      fn -> %{max_size: max_response_queue_size, size: 0, responses: :queue.new()} end,
      name: name
    )
  end

  @doc """
  Adds a `Honeylixir.Response` to the queue unless max size has been reached at
  which point the value is dropped.
  """
  @spec add(Honeylixir.Response.t(), atom()) :: :ok
  def add(%Honeylixir.Response{} = resp, name \\ __MODULE__) do
    Agent.update(name, Honeylixir.ResponseQueue, :do_update, [resp])
  end

  @doc """
  Takes the oldest `Honeylixir.Response` from the queue and returns it unless
  the queue is empty in which case `nil` is returned.
  """
  @spec pop(atom()) :: nil | Honeylixir.Response.t()
  def pop(name \\ __MODULE__) do
    Agent.get_and_update(name, Honeylixir.ResponseQueue, :do_pop, [])
  end

  @doc false
  def do_update(state, %Honeylixir.Response{} = resp) do
    cond do
      state[:size] == state[:max_size] ->
        state

      true ->
        %{state | size: state[:size] + 1, responses: :queue.in(resp, state[:responses])}
    end
  end

  @doc false
  def do_pop(state) do
    case :queue.out(state[:responses]) do
      {:empty, _} ->
        {nil, state}

      {{:value, item}, remaining_queue} ->
        new_state = %{state | size: state[:size] - 1, responses: remaining_queue}
        {item, new_state}
    end
  end
end
