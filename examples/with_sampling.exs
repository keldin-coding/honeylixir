defmodule WithSampling do
  def sample(original_rate, %{"iteration" => i}) when rem(i, 2) == 0 do
    {Honeylixir.DeterminsticSampler.should_sample?(original_rate, i), original_rate}
  end

  def sample(_, %{"iteration" => i}) do
    {Honeylixir.DeterminsticSampler.should_sample?(3, i), 3}
  end

  def sample(rate, fields), do: Honeylixir.default_sample_hook(rate, fields)
end

Application.put_env(:honeylixir, :sample_hook, &WithSampling.sample/2)

:telemetry.attach(
  "test-attach",
  [:honeylixir, :event, :send],
  fn _event_name, _measurements, %{response: %Honeylixir.Response{err: reason, metadata: metadata}}, _config ->
    if reason != nil do
      IO.inspect metadata
    end
  end,
  nil
)

Enum.each(1501..2000, fn i ->
  Honeylixir.Event.create()
  |> Honeylixir.Event.add_field("iteration", i)
  |> Honeylixir.Event.add_metadata(%{"iteration" => i})
  |> Honeylixir.Event.send()
end)

:timer.sleep(1000)
