defmodule Honeylixir.FakeClient do
  use GenServer

  def init(_), do: {:ok, %{}}

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_call({:send_event, event}, _from, state) do
    {:reply, event, [event | state]}
  end

  def handle_call({:pop}, _from, []) do
    {:reply, nil, []}
  end

  def handle_call({:pop}, _from, [latest | rest]) do
    {:reply, latest, rest}
  end

  def handle_call({:clear}, _from, _) do
    {:reply, nil, []}
  end

  def send_event(event) do
    GenServer.call(__MODULE__, {:send_event, event})
    :ok
  end

  def pop() do
    GenServer.call(__MODULE__, {:pop})
  end

  def clear() do
    GenServer.call(__MODULE__, {:clear})
  end
end
