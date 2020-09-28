defmodule DateTimeFake do
  def utc_now(), do: ~U[2020-09-24 04:15:19.345808Z]
end

{:ok, _} = Application.ensure_all_started(:bypass)
ExUnit.start()
