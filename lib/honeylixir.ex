defmodule Honeylixir do
  @moduledoc """
  Used to interact with honeycomb.io's API for tracing and other data.

  ## Installation


  Adding Honeylixir to your mix.exs as a dependency should suffice for installation:

  ```
  def deps() do
    [
      {:honeylixir, "~> 0.2.0"}
    ]
  end
  ```

  ## Configuration

  You can configure any of the following variables via Config:

  |Name|Type|Description|Default|
  |---|---|---|---|
  |`:api_host`|`string`|API to send events to|https://api.honeycomb.io|
  |`:sample_rate`|`integer`|Rate at which events will be sampled represented as a percented. e.g., use 10 to send 10% of events|1|
  |`:team_writekey`|`string`|API key used to send events|`nil`|
  |`:dataset`|`string`/`atom`|Dataset to send the events to|`nil`|
  |`:service_name`|`string`/`atom`|Name of your service which will be added as a field on all events at the key `"service_name"`|`nil`|

  It is required that you set `:team_writekey` and `:dataset` for events to be sent. Otherwise,
  they will return non-200 responses from Honeycomb resulting in the events being dropped. An
  example config may look like so:

  ```
  import Config

  config :honeylixir
    dataset: :"my-company",
    team_writekey: System.get_env("HONEYLIXIR_WRITEKEY"),
    service_name: :my_application
  ```

  Additionally, these are all defined on attributes so you can change them on a
  per event basis if desired.

  ```
  event = Honeylixir.Event.create()
  event = %{event | api_host: "https://some-other-valid-host.com"}
  ```

  ## Usage

  `Honeylixir` provides the ability to make a `Honeylixir.Event`, add fields to it, then send it off asynchronously.

  ```
  Honeylixir.Event.create()
    |> Honeylixir.Event.add_field("a_field", "my_value")
    |> Honeylixir.Event.add_field("something-else", %{"nested" => "value"})
    |> Honeylixir.Event.send()
  ```

  Any value can be used but fields are **REQUIRED** to be strings. Non-string fields
  will result in a no matching function clause error.
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
