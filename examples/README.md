# Honeylixir Examples

## `simple.exs`

This is a small script that relies on the values in `config/dev.exs` You should add a `dev_secret.exs` file to that directory with the following format:

```elixir
import Config

config :honeylixir, team_writekey: "<YOUR WRITE KEY>"
```

This will allow `mix run examples/simple.exs` from the root directory to work. Currently events are sent to the `"honeylixir-test"` dataset by default. You can also override this config in the `dev_secret.exs` file. Once configured, from the root of the project run:

```bash
$ mix run examples/simple.exs
```
