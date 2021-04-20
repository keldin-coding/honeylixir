defmodule Honeylixir.DeterminsticSampler do
  @moduledoc """
  Provides a helper function for sampling consistently for use in the sample_hook.

  This code is an Elixir implemenation of the official beeline-ruby one found
  here: https://github.com/honeycombio/beeline-ruby/blob/v2.4.0/lib/honeycomb/deterministic_sampler.rb
  """
  @moduledoc since: "0.6.0"

  @max_int round(:math.pow(2, 32) - 1)

  @doc """
  Determines if this event should be sampled based on the field given. This way,
  you can deterministically sample given the same value and sample rate with
  every invocation.

  ## Examples

    iex> Honeylixir.DeterminsticSampler.should_sample?(3, "foo")
    true

    iex> Honeylixir.DeterminsticSampler.should_sample?(3, "bar")
    false

    iex> Honeylixir.DeterminsticSampler.should_sample?(1, "bar")
    true

    iex> Honeylixir.DeterminsticSampler.should_sample?(0, "foo")
    false
  """
  @spec should_sample?(integer(), String.Chars.t()) :: boolean()
  def should_sample?(1, _value), do: true
  def should_sample?(rate, _value) when is_integer(rate) and rate <= 0, do: false

  def should_sample?(rate, value) do
    upper_bound = @max_int / rate
    <<val::32, _::bitstring>> = :crypto.hash(:sha256, to_string(value))

    val <= upper_bound
  end
end
