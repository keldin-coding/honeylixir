defmodule Honeylixir.Event do
  @moduledoc """
  Used for managing Events and holding their data. It also has a send function
  that really just kicks off the sending process which happens asynchronously.
  """
  @moduledoc since: "0.1.0"

  # This one is mainly for testing only so we an force a timestamp for comparing

  @typedoc """
  An RFC3339 formatted timestamp

  `"2020-09-29 04:36:15Z"`
  """
  @type rfc_timestamp :: String.t()

  @typedoc """
  A struct containing all the data of an event.

  By default, an event is constructed with the values in the configuration defined
  in `Honeylixir`. Any field can be overwritten via regular struct assigning of values.

  ```
  event = Honeylixir.Event.create()
  event = %{event | api_host: "something-else.com"}
  ```

  An Event also includes two other fields:
  * `fields` - The set of fields which will be sent to Honeycomb as the event body
  * `metadata` - A map of extra data that may be provided as part of a response.
  """
  @type t :: %__MODULE__{
          api_host: String.t(),
          dataset: String.t() | atom(),
          fields: map(),
          metadata: map(),
          sample_rate: integer(),
          team_writekey: String.t(),
          timestamp: rfc_timestamp()
        }
  defstruct [
    :api_host,
    :dataset,
    :sample_rate,
    :team_writekey,
    :timestamp,
    fields: %{},
    metadata: %{}
  ]

  @doc """
  Creates an event using the current timestamp, configured values for sending,
  and no initial fields other than `service_name` if configured.

  ```
  event = Honeycomb.Event.create()
  ```
  """
  @doc since: "0.1.0"
  @spec create() :: t()
  def create(), do: base_event()

  @doc """
  `create/1` accepts either a timestamp or a set of fields to initialize the
  `Honeylixir.Event`.

  ```
  event = Honeylixir.Event.create("2020-09-29 04:36:15Z")
  event = Honeylixir.Event.create(%{"field1" => "value1"})
  ```
  """
  @doc since: "0.1.0"
  @spec create(rfc_timestamp() | map()) :: t()
  def create(fields_or_timestamp)

  def create(%{} = fields) do
    create(utc_timestamp(), fields)
  end

  def create(timestamp) when is_binary(timestamp) do
    %{base_event() | timestamp: timestamp}
  end

  @doc """
  Accepts both a timestamp in RFC3339 format and a map of key/values to
  initialize the Event struct with.
  """
  @doc since: "0.1.0"
  @spec create(rfc_timestamp(), map()) :: t()
  def create(timestamp, %{} = fields) when is_binary(timestamp) do
    event = base_event()
    event = %{event | timestamp: timestamp}

    Honeylixir.Event.add(event, fields)
  end

  @doc """
  Add a single key/value pair to the event.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> Honeylixir.Event.add_field(event, "key", "other").fields
      %{"service_name" => "honeylixir-tests", "key" => "other"}

  """
  @doc since: "0.1.0"
  @spec add_field(t(), String.t(), any()) :: t()
  def add_field(%Honeylixir.Event{} = event, field, value) when is_binary(field) do
    new_fields = Map.put(event.fields, field, value)

    %{event | fields: new_fields}
  end

  @doc """
  Adds a map of fields into the existing set.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> Honeylixir.Event.add(event, %{"another" => "field", "service_name" => "foobar"}).fields
      %{"service_name" => "foobar", "another" => "field"}
  """
  @spec add(Honeylixir.Event.t(), map()) :: t()
  def add(%Honeylixir.Event{} = event, %{} = fieldset) do
    Enum.reduce(fieldset, event, fn {k, v}, acc_event ->
      add_field(acc_event, k, v)
    end)
  end

  @doc """
  Adds to the metadata of the event.

  This information is NOT passed along to LaunchDarkly and should only be used
  by the consuming application to keep track of an event.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> Honeylixir.Event.add_metadata(event, %{"some_key" => "some_value"}).metadata
      %{"some_key" => "some_value"}
  """
  @spec add_metadata(t(), map()) :: t()
  def add_metadata(%Honeylixir.Event{} = event, %{} = metadata) do
    new_metadata = Map.merge(event.metadata, metadata)

    %{event | metadata: new_metadata}
  end

  @doc """
  Used for acknowledging the event is ready for sending, passing it off to
  be sent asynchronously. Currently nothing stops a user from sending the same
  event twice.

  If the event is sampled, a `Honeylixir.Response` is added to the `Honeylixir.ResponseQueue`
  with the `err` attribute set to `:sampled`.
  """
  @spec send(t()) :: :ok
  def send(%Honeylixir.Event{sample_rate: 1} = event),
    do: Honeylixir.TransmissionQueue.enqueue_event(event)

  def send(%Honeylixir.Event{} = event) do
    case Enum.random(1..event.sample_rate) do
      1 ->
        Honeylixir.TransmissionQueue.enqueue_event(event)
        :ok

      _ ->
        Honeylixir.ResponseQueue.add(%Honeylixir.Response{
          metadata: event.metadata,
          duration: 0,
          status_code: nil,
          body: nil,
          err: :sampled
        })

        :ok
    end
  end

  defp base_event() do
    %Honeylixir.Event{
      api_host: api_host(),
      sample_rate: sample_rate(),
      team_writekey: team_writekey(),
      dataset: dataset(),
      timestamp: utc_timestamp()
    }
    |> add_service_name()
  end

  defp utc_timestamp(), do: DateTime.to_string(datetime_module().utc_now())

  defp add_service_name(event) do
    if service_name() != nil do
      add_field(event, "service_name", service_name())
    else
      event
    end
  end

  # Intended mainly for unit testing dependency injection.
  defp datetime_module do
    Application.get_env(:honeylixir, :datetime_module, DateTime)
  end

  defp api_host do
    Application.get_env(:honeylixir, :api_host, "https://api.honeycomb.io")
  end

  defp sample_rate do
    Application.get_env(:honeylixir, :sample_rate, 1)
  end

  defp team_writekey do
    Application.get_env(:honeylixir, :team_writekey)
  end

  defp dataset do
    Application.get_env(:honeylixir, :dataset)
  end

  defp service_name do
    Application.get_env(:honeylixir, :service_name)
  end
end
