defmodule Honeylixir.Transmission do
  @moduledoc """
  Module all about sending things to Honeycomb.
  """

  # Should only be set in test; otherwise the default is what should be used
  @client Application.compile_env(:honeylixir, :client, Honeylixir.Client)

  @doc """
  Asynchronously sends the given event to Honeycomb. The result is *not*
  currently monitored as required by the minimal spec. This should change,
  especially as the larger, full-featured spec requires queueing events for
  transmission in batches. The implementation there may vary in the future.

  Sampling is also handled here as per the spec.
  """
  def send_event(%Honeylixir.Event{sample_rate: 1} = event), do: do_send_event(event)

  def send_event(%Honeylixir.Event{} = event) do
    case Enum.random(1..event.sample_rate) do
      1 ->
        do_send_event(event)

      _ ->
        {:ok, :sampled}
    end
  end

  defp do_send_event(event) do
    Task.start(fn ->
      @client.send_event(event)
    end)

    {:ok, :processed}
  end
end
