defmodule Honeylixir.Client do
  use HTTPoison.Base

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
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            {:ok, nil}

          {:ok, %HTTPoison.Response{body: body}} ->
            {:error, body}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Adds standard headers for all requests that do not vary by data sent.

  ## Examples

      iex> Honeylixir.Client.process_request_headers([])
      [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.1.0"}]

      iex> Honeylixir.Client.process_request_headers([{"X-Foo", "foo"}])
      [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.1.0"}, {"X-Foo", "foo"}]
  """
  @impl true
  def process_request_headers(headers) do
    # Todo: Interpolate the version from what it is
    [{"Content-Type", "application/json"}, {"User-Agent", "libhoney-honeylixir/0.1.0"} | headers]
  end
end
