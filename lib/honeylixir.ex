defmodule Honeylixir do
  @moduledoc """
  Used to interact with honeycomb.io's API for tracing and other data.

  You can configure any of the following variables via Mix.Config:
  :team_writekey -> required to send events. The API key used to send the event.
  :dataset -> required to send events. The default dataset to use for events.

  :api_host -> Defaults to https://api.honeycomb.io. API host to send events to.
  :sample_rate -> The inverse of the sample rate for your events. e.g., if you
    want 10% of events, set this to 10. Defaults to 1, as in 100% of events.
  :service_name -> Defaults to nil. A field for all events going through this
    applications of "service_name" set to this value
  """

  use Application

  @doc false

  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    Application.get_env(:honeylixir, :children_for_test, [])
  end
end
