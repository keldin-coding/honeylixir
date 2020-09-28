defmodule Honeylixir.Event do
  @moduledoc """
  Used for managing Events, not the sending of them.
  """

  @datetime_module Application.get_env(:honeylixir, :datetime_module) || DateTime
  @api_host Application.get_env(:honeylixir, :api_host, "https://api.honeycomb.io")
  @sample_rate Application.get_env(:honeylixir, :sample_rate, 1)
  @team_writekey Application.get_env(:honeylixir, :team_writekey)
  @dataset Application.get_env(:honeylixir, :dataset)
  @service_name Application.get_env(:honeylixir, :service_name)

  @doc """
  By default, an event is constructed with the values in the configuration
  """
  defstruct [
    :timestamp,
    :api_host,
    :sample_rate,
    :team_writekey,
    :dataset,
    fields: %{"service_name" => @service_name}
  ]

  @doc """
  Accepts both a timestamp in RFC3339 format and a map of key/values to
  initialize the Events truct with.
  """
  def create(timestamp, %{} = fields) when is_binary(timestamp) do
    event = %Honeylixir.Event{timestamp: timestamp}
    new_fields = Map.merge(event.fields, fields)

    %{event | fields: new_fields}
  end

  @doc """
  `create/1` accepts either just a timestamp or just a set of fields to set the
  event with.
  """
  def create(%{} = fields) do
    create(utc_timestamp(), fields)
  end

  def create(timestamp) when is_binary(timestamp) do
    %{base_event() | timestamp: timestamp}
  end

  @doc """
  The standard, default way to create an event. No special data and uses the
  current time as the timestamp.
  """
  def create(), do: %{base_event() | timestamp: utc_timestamp()}

  @doc """
  Add a single key/value pair to the event.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> Honeylixir.Event.add_field(event, "key", "other").fields
      %{"service_name" => "honeylixir-tests", "key" => "other"}

  """
  def add_field(%Honeylixir.Event{} = event, field, value) do
    new_fields = Map.put(event.fields, field, value)

    %{event | fields: new_fields}
  end

  @doc """
  Used for acknowledging the event is ready for sending, passing it off to the
  Transmission function to handle the sending.
  """
  def send(%Honeylixir.Event{} = event), do: Honeylixir.Transmission.send_event(event)

  defp base_event() do
    %Honeylixir.Event{
      api_host: @api_host,
      sample_rate: @sample_rate,
      team_writekey: @team_writekey,
      dataset: @dataset
    }
  end

  defp utc_timestamp(), do: DateTime.to_string(@datetime_module.utc_now())
end
