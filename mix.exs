defmodule Honeylixir.MixProject do
  use Mix.Project

  @source_url "https://github.com/lirossarvet/honeylixir"
  @version "0.6.0-dev"

  def project do
    [
      app: :honeylixir,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      elixirc_paths: compiler_paths(Mix.env()),
      package: package()
    ]
  end

  def application do
    [
      mod: {Honeylixir, []},
      extra_applications: [:logger],
      env: []
    ]
  end

  defp package do
    [
      name: "honeylixir",
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end

  defp docs do
    [
      main: Honeylixir,
      source_url: @source_url
    ]
  end

  defp compiler_paths(:test), do: ["test/support"] ++ compiler_paths(:prod)
  defp compiler_paths(_), do: ["lib"]

  defp deps do
    [
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:telemetry, "~> 0.4"},
      {:ex_doc, "~> 0.22", only: :dev},
      {:credo, "~> 1.4.0", only: [:dev], runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp description do
    "Library for interacting with the Honeycomb API"
  end
end
