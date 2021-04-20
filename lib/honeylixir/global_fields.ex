defmodule Honeylixir.GlobalFields do
  @moduledoc """
  Small `Agent` used to store and retrieve fields to be added to all events.
  """
  use Agent

  @doc false
  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Adds a new key value pair to the global state.
  """
  @spec add_field(String.t(), term()) :: :ok
  def add_field(key, value) do
    Agent.update(__MODULE__, fn state -> Map.put(state, key, value) end)
  end

  @doc """
  Removes a field from the global state.
  """
  @spec remove_field(String.t()) :: :ok
  def remove_field(key) do
    Agent.update(__MODULE__, fn state -> Map.delete(state, key) end)
  end

  @doc """
  Gets all global fields
  """
  @spec fields() :: map()
  def fields do
    Agent.get(__MODULE__, & &1)
  end
end
