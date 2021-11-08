import Config

config :honeylixir,
  service_name: "honeylixir-tests",
  datetime_module: DateTimeFake,
  api_host: "https://api.honeycomb.io"

config :logger, compile_time_purge_matching: [
  [level_lower_than: :warning]
]
