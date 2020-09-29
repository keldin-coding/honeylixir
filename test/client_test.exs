defmodule HoneylixirClientTest do
  use ExUnit.Case, async: true
  doctest Honeylixir.Client

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  # This is sort of an uber test case for handling to ensure all the right
  # pieces are in place for the headers and such. We'll test the return value of
  # different HTTP response codes and error modes separately.
  test "send_event/1 - 200 success", %{bypass: bypass} do
    event = event_from_bypass(bypass)

    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/1/events/honeylixir-test"
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
      assert Plug.Conn.get_req_header(conn, "user-agent") == ["libhoney-honeylixir/0.2.0"]

      # Event specific headers
      assert Plug.Conn.get_req_header(conn, "x-honeycomb-team") == [event.team_writekey]
      assert Plug.Conn.get_req_header(conn, "x-honeycomb-event-time") == [event.timestamp]
      # Headers are strings, so we stringify this one.
      assert Plug.Conn.get_req_header(conn, "x-honeycomb-samplerate") == ["#{event.sample_rate}"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      data = Map.put(event.fields, "service_name", "honeylixir-tests")
      assert Jason.encode!(data) == body

      Plug.Conn.resp(conn, 200, "")
    end)

    assert {:ok, nil} == Honeylixir.Client.send_event(event)
  end

  test "send_event/1 - 401", %{bypass: bypass} do
    event = event_from_bypass(bypass)

    response_body = Jason.encode!(%{"error" => "unknown API key - check your credentials"})

    Bypass.expect(bypass, fn conn ->
      assert conn.request_path == "/1/events/honeylixir-test"

      Plug.Conn.resp(conn, 401, response_body)
    end)

    assert {:error, response_body} == Honeylixir.Client.send_event(event)
  end

  test "send_event/1 - failure", %{bypass: bypass} do
    event = event_from_bypass(bypass)

    Bypass.down(bypass)

    assert {:error, %HTTPoison.Error{reason: :econnrefused}} ==
             Honeylixir.Client.send_event(event)
  end

  test "send_event/1 - failed JSON encode" do
    event = Honeylixir.Event.create()
    event = %{event | fields: "\xFF"}

    assert {:error, %Jason.EncodeError{message: "invalid byte 0xFF in <<255>>"}} ==
             Honeylixir.Client.send_event(event)
  end

  test "process_request_headers/1" do
    assert Honeylixir.Client.process_request_headers([{"foobar", "amazing"}]) == [
             {"Content-Type", "application/json"},
             {"User-Agent", "libhoney-honeylixir/0.2.0"},
             {"foobar", "amazing"}
           ]
  end

  defp event_from_bypass(bypass) do
    event = Honeylixir.Event.create()

    %{
      event
      | api_host: "http://localhost:#{bypass.port}",
        dataset: "honeylixir-test",
        team_writekey: "abc"
    }
  end
end
