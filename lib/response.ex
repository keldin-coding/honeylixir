defmodule Honeylixir.Response do
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
          duration: integer(),
          status_code: nil | integer(),
          body: nil | String.t(),
          err: nil | :overflow | :sampled
        }
  defstruct @enforce_fields
end
