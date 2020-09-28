import Config

config :honeylixir, service_name: "honeylixir-tests"
config :honeylixir, datetime_module: DateTimeFake
config :honeylixir, client: Honeylixir.FakeClient
config :honeylixir, children_for_test: [{Honeylixir.FakeClient, []}]
