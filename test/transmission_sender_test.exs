defmodule HoneylixirTransmissionSenderTest do
  use ExUnit.Case, async: false
  doctest Honeylixir.TransmissionSender

  defmodule ResponseTestQueue do
    use Agent

    def start_link(_) do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def add(response) do
      Agent.update(__MODULE__, fn state -> state ++ [response] end)
    end

    def pop do
      Agent.get_and_update(__MODULE__, fn [head | rest] -> {head, rest} end)
    end
  end

  setup do
    bypass = Bypass.open()
    start_supervised!(ResponseTestQueue)

    :telemetry.attach(
      "add-to-response-stack",
      [:honeylixir, :event, :send],
      fn _, _, %{response: response}, _ ->
        ResponseTestQueue.add(response)
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach("add-to-response-stack") end)

    {:ok, bypass: bypass}
  end

  test "send_batch/1 - success", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      assert conn.method == "POST"

      Plug.Conn.resp(
        conn,
        200,
        Jason.encode!([%{status: 202}, %{status: 401, error: "unknown api key"}])
      )
    end)

    event_1 = Honeylixir.Event.create() |> Honeylixir.Event.add_metadata(%{"success" => true})
    event_2 = Honeylixir.Event.create() |> Honeylixir.Event.add_metadata(%{"success" => false})
    events = [event_1, event_2]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{"success" => true}
    assert resp_1.status_code == 202
    assert resp_1.body == ""
    assert resp_1.err == nil

    assert resp_2.metadata == %{"success" => false}
    assert resp_2.status_code == 401
    assert resp_2.body == "unknown api key"
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - failure from HC", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 401, Jason.encode!(%{error: "unknown api key"}))
    end)

    events = [event_with_metadata(%{id: 1}), event_with_metadata(%{id: 2})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 1}
    assert resp_2.metadata == %{id: 2}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == 401
    assert resp_2.status_code == 401

    assert resp_1.body == "unknown api key"
    assert resp_2.body == "unknown api key"

    assert resp_1.err == nil
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - random error", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, Jason.encode!("upstream disconnect"))
    end)

    events = [event_with_metadata(%{id: 3}), event_with_metadata(%{id: 4})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 3}
    assert resp_2.metadata == %{id: 4}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == 500
    assert resp_2.status_code == 500

    assert resp_1.body == "upstream disconnect"
    assert resp_2.body == "upstream disconnect"

    assert resp_1.err == nil
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - unknown error", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 504, "")
    end)

    events = [event_with_metadata(%{id: 6}), event_with_metadata(%{id: 7})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 6}
    assert resp_2.metadata == %{id: 7}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == 504
    assert resp_2.status_code == 504

    assert resp_1.body == "unknown error"
    assert resp_2.body == "unknown error"

    assert resp_1.err == nil
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - unknown non-map error", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, Jason.encode!(["invalid request"]))
    end)

    events = [event_with_metadata(%{id: 8}), event_with_metadata(%{id: 9})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 8}
    assert resp_2.metadata == %{id: 9}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == 500
    assert resp_2.status_code == 500

    assert resp_1.body == ["invalid request"]
    assert resp_2.body == ["invalid request"]

    assert resp_1.err == nil
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - unknown map error", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, Jason.encode!(%{something: "not-error"}))
    end)

    events = [event_with_metadata(%{id: 10}), event_with_metadata(%{id: 11})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 10}
    assert resp_2.metadata == %{id: 11}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == 500
    assert resp_2.status_code == 500

    assert resp_1.body == "unknown error"
    assert resp_2.body == "unknown error"

    assert resp_1.err == nil
    assert resp_2.err == nil

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  test "send_batch/1 - connection error", %{bypass: bypass} do
    old_api_host = Application.get_env(:honeylixir, :api_host)
    Application.put_env(:honeylixir, :api_host, "http://localhost:#{bypass.port}")

    Bypass.down(bypass)

    events = [event_with_metadata(%{id: 12}), event_with_metadata(%{id: 13})]

    assert Honeylixir.TransmissionSender.send_batch(events) == :ok

    resp_1 = ResponseTestQueue.pop()
    resp_2 = ResponseTestQueue.pop()

    assert resp_1.metadata == %{id: 12}
    assert resp_2.metadata == %{id: 13}

    assert is_integer(resp_1.duration)
    assert is_integer(resp_2.duration)

    assert resp_1.status_code == nil
    assert resp_2.status_code == nil

    assert resp_1.body == nil
    assert resp_2.body == nil

    assert resp_1.err == :http_error
    assert resp_2.err == :http_error

    Application.put_env(:honeylixir, :api_host, old_api_host)
  end

  defp event_with_metadata(metadata) do
    Honeylixir.Event.create() |> Honeylixir.Event.add_metadata(metadata)
  end
end
