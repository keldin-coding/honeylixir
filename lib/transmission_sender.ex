defmodule Honeylixir.TransmissionSender do
  @unknown_error "unknown error"

  @moduledoc """
  Typically invoked as a Task, handles sending the `Honeylixir.Event` batches to
  the `Honeylixir.Client` and adding responses to the queue.
  """

  @doc """
  Does the actual passoff to the `Honeylixir.Client` for sending.

  Responses are sent via `:telemetry.execute/3`.
  """
  @spec send_batch(list(Honeylixir.Event.t())) :: :ok
  def send_batch(events) do
    case Honeylixir.Client.send_batch(events) do
      {:ok, response, duration} ->
        responses = Jason.decode!(response.body)

        process_event_responses(
          events,
          responses,
          System.convert_time_unit(duration, :native, :millisecond)
        )

      {:failure, response, duration} ->
        error_body = error_response_body(Jason.decode(response.body))

        responses =
          Enum.map(events, fn _ ->
            %{"status" => response.status_code, "error" => error_body}
          end)

        process_event_responses(events, responses, duration)

      {:error, %HTTPoison.Error{}, duration} ->
        Enum.each(events, fn event ->
          :telemetry.execute(
            Honeylixir.event_send_telemetry_key(),
            %{},
            %{response: Honeylixir.Response.http_error_response(event, duration)}
          )
        end)

        :ok
    end
  end

  defp error_response_body({:ok, body}) when is_map(body),
    do: Map.get(body, "error", @unknown_error)

  defp error_response_body({:ok, body}), do: body

  defp error_response_body({:error, %Jason.DecodeError{data: data}}) when data == "",
    do: @unknown_error

  defp error_response_body({:error, %Jason.DecodeError{data: data}}), do: data

  defp process_event_responses([], [], _), do: :ok

  defp process_event_responses([event | rest], [%{"status" => 202} | response_rest], duration) do
    :telemetry.execute(
      Honeylixir.event_send_telemetry_key(),
      %{},
      %{response: Honeylixir.Response.success_response(event, duration, 202)}
    )

    process_event_responses(rest, response_rest, duration)
  end

  defp process_event_responses(
         [event | rest],
         [%{"error" => error_body, "status" => status_code} | response_rest],
         duration
       ) do
    :telemetry.execute(
      Honeylixir.event_send_telemetry_key(),
      %{},
      %{response: Honeylixir.Response.failure_response(event, duration, status_code, error_body)}
    )

    process_event_responses(rest, response_rest, duration)
  end
end
