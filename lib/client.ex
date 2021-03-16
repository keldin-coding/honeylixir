defmodule Honeylixir.Client do
  @moduledoc false

  use HTTPoison.Base

  # Function responsible for sending the event off to Honeycomb. Handles adding
  # headers required, constructing the URI, and finally sending it off.
  # @spec send_event(Honeylixir.Event.t()) :: {:ok | :error, nil | String.t() | HTTPoison.Error.t()}
  def send_event(%Honeylixir.Event{} = event) do
    url = "#{event.api_host}/1/events/#{event.dataset}"

    case Jason.encode(event.fields) do
      {:ok, body} ->
        headers = [
          {"X-Honeycomb-Team", event.team_writekey},
          {"X-Honeycomb-Event-Time", event.timestamp},
          {"X-Honeycomb-Samplerate", event.sample_rate}
        ]

        case post(url, body, headers, hackney: [pool: :default]) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            {:ok, body}

          {:ok, %HTTPoison.Response{body: body}} ->
            {:failure, body}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def send_batch([]), do: {:ok, nil}

  def send_batch(events) when is_list(events) do
    [first_event | _] = events

    url = "#{first_event.api_host}/1/batch/#{first_event.dataset}"

    sendable_events =
      Enum.map(events, fn event ->
        %{data: event.fields, time: event.timestamp, samplerate: event.sample_rate}
      end)

    body = Jason.encode!(sendable_events) |> :zlib.gzip()

    headers = [
      {"Content-Encoding", "gzip"},
      {"X-Honeycomb-Team", first_event.team_writekey}
    ]

    start = System.monotonic_time()
    result = post(url, body, headers, hackney: [pool: :default])
    # Perform a little quick calculation to get our native time into microseconds
    # then divide by a thousand to get a floating point millisecond duration.
    duration =
      (System.monotonic_time() - start)
      |> System.convert_time_unit(:native, :microsecond)

    duration = Float.round(duration / 1000, 3)

    case result do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        {:ok, response, duration}

      {:ok, %HTTPoison.Response{} = response} ->
        {:failure, response, duration}

      {:error, error} ->
        {:error, error, duration}
    end
  end

  # Adds standard headers for all requests that do not vary by data sent.
  #
  # ## Examples
  #
  #     iex> Honeylixir.Client.process_request_headers([])
  #     [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.5.1"}]
  #
  #     iex> Honeylixir.Client.process_request_headers([{"X-Foo", "foo"}])
  #     [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.5.1"}, {"X-Foo", "foo"}]
  @impl true
  def process_request_headers(headers) do
    # TODO: Interpolate the version from what it is
    [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.5.1"} | headers]
  end
end
