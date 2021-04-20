# Honeylixir

[![CircleCI](https://circleci.com/gh/lirossarvet/honeylixir.svg?style=shield)](https://circleci.com/gh/lirossarvet/honeylixir)

This is intended to be a client for usage in hitting the [Honeycomb.io](https://www.honeycomb.io) APIs for sending events geared toward observability.

## Installation

Available via HEx, the package can be installed by adding `honeylixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:honeylixir, "~> 0.6.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/honeylixir](https://hexdocs.pm/honeylixir).

## Usage

Please visit the [Hexdocs site](https://hexdocs.pm/honeylixir) for the latest documentation around usage and configuration.

## Related works

* [libhoney-ex](https://github.com/carwow/libhoney-ex) - the first Elixir Honeycomb client I stumbled upon
* [opencensus_honeycomb](https://github.com/opencensus-beam/opencensus_honeycomb) - a fully fledged OpenCensus implementation for Honeycomb. I definitely liked the idea of using `:telemetry` in their project and adopted something similar in mine. Fewer Processes == fewer places for things to go wrong.
