defmodule Honeylixir.Response do
  @moduledoc """
  Struct and factory functions for generating certain kinds of Responses.
  """

  @enforce_fields [:metadata, :duration, :status_code, :body, :err]

  @typedoc """
  Response object with data about an event after a send attempt.

  * `metadata` - the metadata from the Event a user can use to correlate this response with a specific event
  * `duration` - time in ms it took to send the event, HTTP time only.
  * `status_code` - status code for this event from Honeycomb
  * `body` - the body associated with this event
  * `err` - set if an error occurs in sending, such as a max queue size overflow or when the event is sampled
  """
  @type t :: %__MODULE__{
          metadata: map(),
          duration: float(),
          status_code: nil | integer(),
          body: nil | String.t(),
          err: nil | :overflow | :sampled | :http_error
        }
  defstruct @enforce_fields

  @doc """
  Creates a `Honeylixir.Response` for an event that got sampled.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> event = %{event | metadata: %{id: 1}}
      iex> Honeylixir.Response.sampled_response(event)
      %Honeylixir.Response{metadata: %{id: 1}, duration: 0, status_code: nil, body: nil, err: :sampled}
  """
  @spec sampled_response(Honeylixir.Event.t()) :: t()
  def sampled_response(%Honeylixir.Event{} = event) do
    %Honeylixir.Response{
      metadata: event.metadata,
      duration: 0,
      status_code: nil,
      body: nil,
      err: :sampled
    }
  end

  @doc """
  Creates a `Honeylixir.Response` for an event that got dropped due to queue overflow.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> event = %{event | metadata: %{id: 1}}
      iex> Honeylixir.Response.overflow_response(event)
      %Honeylixir.Response{metadata: %{id: 1}, duration: 0, status_code: nil, body: nil, err: :overflow}
  """
  @spec overflow_response(Honeylixir.Event.t()) :: t()
  def overflow_response(%Honeylixir.Event{} = event) do
    %Honeylixir.Response{
      metadata: event.metadata,
      duration: 0,
      status_code: nil,
      body: nil,
      err: :overflow
    }
  end

  @doc """
  Creates a `Honeylixir.Response` for an event was successfully sent.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> event = %{event | metadata: %{id: 1}}
      iex> Honeylixir.Response.success_response(event, 10.2232, 202)
      %Honeylixir.Response{metadata: %{id: 1}, duration: 10.2232, status_code: 202, body: "", err: nil}
  """
  @spec success_response(Honeylixir.Event.t(), float(), integer()) :: t()
  def success_response(%Honeylixir.Event{} = event, duration, status_code) do
    %Honeylixir.Response{
      metadata: event.metadata,
      duration: duration,
      status_code: status_code,
      body: "",
      err: nil
    }
  end

  @doc """
  Creates a `Honeylixir.Response` for an event was sent but not accepted by Honeycomb.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> event = %{event | metadata: %{id: 1}}
      iex> Honeylixir.Response.failure_response(event, 10.2232, 401, "unknown api key")
      %Honeylixir.Response{metadata: %{id: 1}, duration: 10.2232, status_code: 401, body: "unknown api key", err: nil}
  """
  @spec failure_response(Honeylixir.Event.t(), float(), integer(), String.t()) :: t()
  def failure_response(%Honeylixir.Event{} = event, duration, status_code, body) do
    %Honeylixir.Response{
      metadata: event.metadata,
      duration: duration,
      status_code: status_code,
      body: body,
      err: nil
    }
  end

  @doc """
  Creates a `Honeylixir.Response` for an event that was attempted to be sent but failed due to
  unforeseen HTTP issues, such as a refused connection.

  ## Examples

      iex> event = Honeylixir.Event.create()
      iex> event = %{event | metadata: %{id: 1}}
      iex> Honeylixir.Response.http_error_response(event, 10.2232)
      %Honeylixir.Response{metadata: %{id: 1}, duration: 10.2232, status_code: nil, body: nil, err: :http_error}
  """
  @spec http_error_response(Honeylixir.Event.t(), float()) :: t()
  def http_error_response(%Honeylixir.Event{} = event, duration) do
    %Honeylixir.Response{
      metadata: event.metadata,
      duration: duration,
      status_code: nil,
      body: nil,
      err: :http_error
    }
  end
end
