import Config

config :honeylixir, :dataset, System.get_env("HONEYLIXIR_DATASET", "honeylixir")
config :honeylixir, :team_writekey, System.get_env("HONEYLIXIR_WRITEKEY")
config :honeylixir, :service_name, :honeylixir
