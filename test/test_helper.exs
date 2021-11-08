defmodule DateTimeFake do
  def utc_now(), do: ~U[2020-09-24 04:15:19.345808Z]
end

Logger.configure([level: :warning])

defmodule HoneylixirTestListener do
  @moduledoc """
  Small `Agent` used to store and retrieve fields to be added to all events.
  """
  use Agent

  @doc false
  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def seen(id, err) do
    Agent.update(__MODULE__, fn state -> Map.put(state, id, err) end)
  end

  def values() do
    Agent.get(__MODULE__, & &1)
  end
end

{:ok, _} = Application.ensure_all_started(:bypass)
ExUnit.start()
