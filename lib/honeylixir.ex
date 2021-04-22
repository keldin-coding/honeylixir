defmodule Honeylixir do
  @version Mix.Project.config()[:version]
  @moduledoc """
  Used to interact with Honeycomb's API for sending events.

  ## Installation

  Adding Honeylixir to your mix.exs as a dependency should suffice for installation:

  ```
  def deps() do
    [
      {:honeylixir, "~> 0.7.0"}
    ]
  end
  ```

  ## Configuration

  You can configure any of the following variables via Config:

  |Name|Type|Description|Default|
  |---|---|---|---|
  |`:api_host`|`string`|API to send events to|https://api.honeycomb.io|
  |`:sample_rate`|`integer`|Default rate at which events will be sampled represented as a percented. e.g., use 10 to send 10% of events|1|
  |`:sample_hook`|function/2|Arity 2 function accepting the sample rate originally on the event and all fields at the time of sending as the second|N/A|
  |`:team_writekey`|`string`|API key used to send events|`nil`|
  |`:dataset`|`string`/`atom`|Dataset to send the events to|`nil`|
  |`:service_name`|`string`/`atom`|Name of your service which will be added as a field on all events at the key `"service_name"`|`nil`|
  |`:max_queue_size`|`integer`|How large the transmission queue can grow before events are dropped|`10_000`|
  |`:batch_size`|`integer`|How many events to send per batch|`50`|
  |`:batch_timing`|`integer`|Time in milliseconds to try sending events from the queue in a batch|`100`|
  |`:max_send_processes`|`integer`|How many Processes to use for sending events in the background|`30`|

  It is required that you set `:team_writekey` and `:dataset` for events to be sent. Otherwise,
  they will return non-200 responses from Honeycomb resulting in the events being dropped. An
  example config may look like so (whether distillery or compile time Mix):

  ```
  config :honeylixir,
    dataset: :"my-company",
    team_writekey: System.get_env("HONEYLIXIR_WRITEKEY"),
    service_name: :my_application
  ```

  Additionally, many are defined on the `Honeylixir.Event` struct and can be overridden
  on a per-event basis. Please check its typspec for a complete list of what you can
  modify.

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
    |> Honeylixir.Event.add(%{"field 4" => 4, "field 5" => :ok})
    |> Honeylixir.Event.send()
  ```

  Any value that dervices the `Jason.Encoder` protocol can be used, but fields are
  **REQUIRED** to be strings. Non-string fields will result in a no matching function
  clause error.

  ### Global field configuration

  `Honeylixir` supports adding global fields which will be added to all events on
  event creation. You can add, remove, or view the fields configured at any time.

  ```
  Honeylixir.GlobalFields.add_field("my-thing", "special")

  event = Honeylixir.Event.create()
  IO.inspect(event.fields)
  # => %{"my-thing" => "special"}

  IO.inspect Honeylixir.GlobalFields.fields
  # => %{"my-thing", "special"}

  Honeylixir.GlobalFields.remove_field("my-thing")
  IO.inspect Honeylixir.GlobalFields.fields
  # => %{}
  ```

  ### Configuring Sampling

  You can configure a `sample_hook` that is invoked when an event is sent. This is called first to determine if the
  event will actually be sent to Honeycomb. The expected way to use this is to pass a function using `&Module.function/2`
  syntax. If you are using pattern matching in your sample hook and aren't covering all cases on your own, you can set
  the catch-all sample hook to call the `default_sample_hook` in this package.

  ```
  defmodule MyApp.HoneycombSampling do
    def sample(original_rate, %{"user_id" => user_id}) do
      {Honeylixir.DeterinsticSampler.should_sample?(original_rate, user_id), original_rate}
    end
    def sample(original_rate, fields), do: Honeylixir.default_sample_hook(original_rate, fields)
  end

  config :honeylixir, sample_hook: &MyApp.HoneycombSampling.sample/2
  ```

  ### Builder pattern

  Currently, the Builder pattern is supported insomuch as Elixir's syntax allows it. That is to say, you can create
  your own function that acts as a Builder.

  ```
  defmodule MyHoneylixirBuilders do
    def http_event do
      Honeylixir.Event.create()
      |> Honeylixir.add_field("foo", "bar")
    end

    def different_dataset_event do
      %{Honeylixir.Event.create() | dataset: "my-other-dataset"}
      |> Honeylixir.add_field("something", "great")
      |> Honeylixir.add_field("another", "thing")
    end
  end
  ```

  ### Checking responses

  By attaching metadata to your events, you can pull `Honeylixir.Response`s to see what happened
  to your event. These are sent along via `:telemetry` for getting events as part of the `metadata`
  object at the `:response` field. Current eventNames:

  * `[:honeylixir, :event, :send]` - Used for the response around any event sent, even if that event is sampled or rejected for queue overflow. Metadata is set to `%{response: %Honeylixir.Response}` which contains the data.

  ```
  # Note: as stated in the `:telemetry` docs, you should use function capture rather than anonymous functions.
  :telemetry.attach(
    "test-attachment",
    [:honeylixir, :event, :send],
    fn _event_name, _measurements, %{response: response}, _config ->
      IO.inspect response
    end,
    nil
  )

  Honeylixir.Event.create() |> Honeylixir.Event.send()
  # wait for event to async send off and the associated Response will be output
  ```

  You can also attach to the function used for key creation:

  ```
  :telemetry.attach(
    "my-listener",
    Honeylixir.event_send_telemetry_key(),
    fn _, _, _, _ -> nil end,
    nil
  )
  ```
  """

  @typedoc """
  Function signature required of the function passed as a sample_hook. It takes in
  the sample rate as it is set on the event in question as well as all the fields
  that would be sent. The return value should be a tuple of a boolean and integer.
  The boolean indicates if the event should, in fact, be sent to Honeycomb. The
  integer is the sample rate as should be reported to Honeycomb for extrapolation.
  """
  @type sample_function :: (integer(), Honeylixir.Event.fields_map() -> {boolean(), integer()})

  use Application

  @doc false
  def start(_type, _args) do
    Supervisor.start_link(children(), strategy: :one_for_one)
  end

  defp children do
    [
      Honeylixir.GlobalFields,
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

  @doc """
  Key used for all event send telemetry executions.
  """
  @spec event_send_telemetry_key() :: list()
  def event_send_telemetry_key, do: [:honeylixir, :event, :send]

  @doc """
  Randomly samples your events according to the rate given by generating a random
  ID for your event which is then used to determine sampling.
  """
  def default_sample_hook(rate, _) do
    {Honeylixir.DeterminsticSampler.should_sample?(rate, generate_short_id()), rate}
  end

  @doc false
  def version(), do: @version

  @doc false
  def sample_hook() do
    Application.get_env(:honeylixir, :sample_hook, &default_sample_hook/2)
  end
end
