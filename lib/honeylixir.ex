defmodule Honeylixir do
  @moduledoc """
  Used to interact with honeycomb.io's API for tracing and other data.

  ## Installation


  Adding Honeylixir to your mix.exs as a dependency should suffice for installation:

  ```
  def deps() do
    [
      {:honeylixir, "~> 0.3.0"}
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
  |`:max_queue_size`|`integer`|How large the transmission queue can grow before events are dropped|`10_000`|
  |`:batch_size`|`integer`|How many events to send per batch|`50`|
  |`:batch_timing`|`integer`|Time in milliseconds to try sending events from the queue in a batch|`100`|
  |`:max_send_processes`|`integer`|How many Processes to use for sending events in the background|`30`|
  |`:max_response_queue_size`|`integer`|How many responses for event sending can be held in the queue. Once reached, responses are dropped|`100`|


  It is required that you set `:team_writekey` and `:dataset` for events to be sent. Otherwise,
  they will return non-200 responses from Honeycomb resulting in the events being dropped. An
  example config may look like so (whether distillery or compile time Mix):

  ```
  config :honeylixir,
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

  ### Sending events

  `Honeylixir` provides the ability to make a `Honeylixir.Event`, add fields to it, then send it off asynchronously.

  ```
  Honeylixir.Event.create()
    |> Honeylixir.Event.add_field("a_field", "my_value")
    |> Honeylixir.Event.add_field("something-else", %{"nested" => "value"})
    |> Honeylixir.Event.send()
  ```

  Any value can be used but fields are **REQUIRED** to be strings. Non-string fields
  will result in a no matching function clause error.

  ### Checking responses

  By attaching metadata to your events, you can pull `Honeylixir.Response`s to see what happened
  to your event. This data is stored in the `Honeylixir.ResponseQueue` which acts as a small
  data store.

  ```
  Honeylixir.Event.create() |> Honeylixir.Event.send()
  # wait for event to async send off
  resp = Honeylixir.ResponseQueue.pop()
  ```
  """

  use Application

  @doc false
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      {Honeylixir.ResponseQueue,
       %{
         max_response_queue_size: Application.get_env(:honeylixir, :max_response_queue_size, 100)
       }},
      {Honeylixir.TransmissionQueue,
       %{
         max_queue_size: Application.get_env(:honeylixir, :max_queue_size, 10_000),
         batch_size: Application.get_env(:honeylixir, :batch_size, 50),
         batch_timing: Application.get_env(:honeylixir, :batch_timing, 100)
       }},
      {Task.Supervisor,
       name: Honeylixir.TransmissionSupervisor,
       max_children: Application.get_env(:honeylixir, :max_send_processes, 30)}
    ]
  end

  @doc """
  Generates a random string of 16 bytes encoded in base 16.
  """
  @spec generate_long_id() :: String.t()
  def generate_long_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @doc """
  Generates a random string of 8 bytes encoded in base 16.
  """
  @spec generate_short_id() :: String.t()
  def generate_short_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
