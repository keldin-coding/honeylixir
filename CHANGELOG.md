# 0.6.0

* **IMPORTANT**: Update HTTPoison dependency because of some SSL warnings
* Add `Honeylixir.DeterministicSampler` with a function to sampled based on a field
* Add support for a `sample_hook` that users can provide
* Re-organize files to have a `honeylixir` directory to match module naming

# 0.5.1

* Add `:logger` as a required extra application

# 0.5.0

* Confirmed support for Elixir `~> 1.9` [#3](https://github.com/lirossarvet/honeylixir/pull/3)
* Switch to CircleCI for testing
* Update timestamps to be ISO8601 UTC

# 0.4.0

* Cleaned up mix.exs file [#2](https://github.com/lirossarvet/honeylixir/pull/2)
* **BREAKING** Removed the `ResponseQueue` in favor of `:telemetry` execution
* Notably adjust `duration` as determined in the `Honeylixir.Response` object to be a floating point number of milliseconds, such that something taking 100 microseconds is represented roughly as 0.1.
* Add support for Global field configuration
* No longer drop events when `max_children` is reached and no more `TransmissionSender`s can be started
* `TransmissionQueue` continuously tries to empty itself

# 0.3.0

* **BREAKING**: Change LICENSE from MIT to Apache-2.0
* **BREAKING**: `Honeylixir.Transmission` no longer has a singular `send_event` for sending individually. If you want to explicitly send an event rather than queueing it up for background sending, please use `Honeylixir.Client.send_event/1` directly.
* Support queueing events and sending in batches
* Provide `Honeylixir.Response` for storing data about event send attempts and `Honeylixir.ResponseQueue` to pull them.

# 0.2.0

* Add fuller documentation
* Updated `service_name` not to be set to `nil` on the event if it isn't configured

# 0.1.0

* Support creating and sending basic events
