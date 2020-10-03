Honeylixir.Event.create()
|> Honeylixir.Event.add_field("test-field", "honeylixir-simple")
|> Honeylixir.Event.add_field("mix", "run")
|> Honeylixir.Event.send()

Enum.each(501..1000, fn i ->
  Honeylixir.Event.create()
  |> Honeylixir.Event.add_field("iteration", i)
  |> Honeylixir.Event.send()
end)

# We sleep because currently there are no trappings to ensure events are sent
# on program exit. The desired behavior there is still in question.
:timer.sleep(800)
