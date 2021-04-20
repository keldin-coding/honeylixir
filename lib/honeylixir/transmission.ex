defmodule Honeylixir.Transmission do
  @moduledoc """
  Transmission engine that handles sending events to the expected place.

  Events have a complicated lifetime from being sent here, possibly sampled out,
  enqueued, then finally asynchronously sent in a batch. This handles figuring
  out where it needs to go, sort of like a router and initialy processor for
  sending events.
  """

  @doc """
  Handles sending the batch to a transmission sender task to be processed
  asynchronously.
  """
  @spec send_batch(list(Honeylixir.Event.t())) :: none()
  def send_batch(events) when is_list(events) do
    Task.Supervisor.start_child(
      Honeylixir.TransmissionSupervisor,
      Honeylixir.TransmissionSender,
      :send_batch,
      [events]
    )
  end
end
