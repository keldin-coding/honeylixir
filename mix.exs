defmodule Honeylixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :honeylixir,
      version: "0.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      source_url: "https://github.com/lirossarvet/honeylixir",
      description: description(),
      elixirc_paths: compiler_paths(Mix.env()),
      docs: [
        main: Honeylixir
      ],

      # Package
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Honeylixir, []},
      extra_applications: [],
      env: []
    ]
  end

  defp package do
    [
      name: "honeylixir",
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/lirossarvet/honeylixir"}
    ]
  end

  defp compiler_paths(:test), do: ["test/support"] ++ compiler_paths(:prod)
  defp compiler_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.22", only: :dev},
      {:bypass, "~> 2.0.0",
       git: "https://github.com/josevalim/bypass.git", branch: "jv-latest-cowboy", only: :test}
      # {:jason, ">= 0.1.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description do
    "Library for interacting with the Honeycomb API"
  end
end
