defmodule Honeylixir.TransmissionQueue do
  @moduledoc """
  Queue for processing and managing events to be sent.
  """
  use GenServer

  require Logger

  @internal_fields [:batch_timing, :max_queue_size, :batch_size]

  @enforce_fields [:size, :items]
  defstruct @enforce_fields

  @type t_queue_key :: {String.t(), String.t(), String.t()}

  # Helpers

  # Creates the key for our queues in the state based on the given event.

  # The Honeycomb sdk spec requires grouping events into batches based on api host,
  # dataset, and writekey.
  defp queue_key(%Honeylixir.Event{} = event) do
    {event.api_host, event.team_writekey, event.dataset}
  end

  # Client-side

  @doc false
  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  @doc """
  Accepts an event and asynchronously adds it to the queue for processing.
  """
  @spec enqueue_event(Honeylixir.Event.t()) :: :ok
  def enqueue_event(%Honeylixir.Event{} = event) do
    GenServer.cast(__MODULE__, {:enqueue_event, event})
  end

  @doc """
  Asynchronously instructs the GenServer to prepare a batch for the given key
  to be sent.
  """
  @spec process_batch(t_queue_key()) :: :ok
  def process_batch({_api_host, _team_writekey, _dataset} = queue_key) do
    GenServer.cast(__MODULE__, {:process_batch, queue_key})
  end

  @doc """
  Synchronously pulls all known queue keys from the state
  """
  @spec get_all_queue_keys() :: list(t_queue_key())
  def get_all_queue_keys() do
    GenServer.call(__MODULE__, :get_all_queue_keys)
  end

  # Server-side
  #
  # Errors here would be bad and potentially crash the queue server.
  @impl true
  def init(%{batch_timing: batch_timing, max_queue_size: _, batch_size: _} = config) do
    Process.send_after(self(), :process_all_batches, batch_timing)

    {:ok, config}
  end

  @impl true
  def handle_call(:get_all_queue_keys, _from, state) do
    keys =
      Enum.reduce(@internal_fields, Map.keys(state), fn i, acc ->
        List.delete(acc, i)
      end)

    {:reply, keys, state}
  end

  @impl true
  def handle_cast(
        {:enqueue_event, %Honeylixir.Event{} = event},
        %{max_queue_size: max_queue_size, batch_size: batch_size} = state
      ) do
    current_key = queue_key(event)

    queue_for_event =
      Map.get(state, current_key, %Honeylixir.TransmissionQueue{size: 0, items: :queue.new()})

    if queue_for_event.size >= max_queue_size do
      # This should also technically add to the response queue that the queue for
      # sending messages is full.
      :telemetry.execute(
        Honeylixir.event_send_telemetry_key(),
        %{},
        %{response: Honeylixir.Response.overflow_response(event)}
      )

      {:noreply, state}
    else
      queue_for_event = %Honeylixir.TransmissionQueue{
        size: queue_for_event.size + 1,
        items: :queue.in(event, queue_for_event.items)
      }

      if queue_for_event.size >= batch_size do
        # I'm choosing to explicitly name the Module and function here as a signal
        # to myself and future me that this is passing another message to the same
        # server to be processed.
        Honeylixir.TransmissionQueue.process_batch(current_key)
      end

      {:noreply, Map.put(state, current_key, queue_for_event)}
    end
  end

  @impl true
  def handle_cast(
        {:process_batch, {_api_host, _team_writekey, _dataset} = queue_key},
        %{batch_size: batch_size} = state
      ) do
    # Using `nil` for items might be dangerous here, but it's entirely unused. We
    # exit ahead of every accessing items so we may as well save the minor memory
    # and time cost.
    queue_for_batch =
      Map.get(state, queue_key, %Honeylixir.TransmissionQueue{size: 0, items: nil})

    current_batch_size = Enum.min([queue_for_batch.size, batch_size])

    _handle_process_batch(state, queue_for_batch, queue_key, current_batch_size)
  end

  @impl true
  def handle_info(:process_all_batches, %{batch_timing: batch_timing} = state) do
    keys =
      Enum.reduce(@internal_fields, Map.keys(state), fn i, acc ->
        List.delete(acc, i)
      end)

    Enum.each(keys, &process_batch(&1))

    Process.send_after(self(), :process_all_batches, batch_timing)

    {:noreply, state}
  end

  defp _handle_process_batch(state, _, _, current_batch_size) when current_batch_size == 0,
    do: {:noreply, state}

  defp _handle_process_batch(
         state,
         %Honeylixir.TransmissionQueue{} = queue_for_batch,
         {_api_host, _team_writekey, _dataset} = queue_key,
         current_batch_size
       ) do
    {batch, remaining_items} =
      Enum.reduce(
        1..current_batch_size,
        {[], queue_for_batch.items},
        fn _, {batch, current_queue} ->
          case :queue.out(current_queue) do
            {{:value, item}, remaining_queue} ->
              batch = [item | batch]
              {batch, remaining_queue}

            {:empty, remaining_queue} ->
              {batch, remaining_queue}
          end
        end
      )

    # Handle the task supervisor being at max and rejecting creation here. Most
    # likely by setting new state to old state and carrying on.
    case Honeylixir.Transmission.send_batch(batch) do
      {:ok, _} ->
        new_state =
          Map.put(state, queue_key, %Honeylixir.TransmissionQueue{
            size: queue_for_batch.size - current_batch_size,
            items: remaining_items
          })

        {:noreply, new_state}

      {:error, :max_children} ->
        Logger.warn("Cannot start new sender, max children already running")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end
end
