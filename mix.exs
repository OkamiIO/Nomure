defmodule Nomure.MixProject do
  use Mix.Project

  def project do
    [
      app: :nomure,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      # compilers: [:rustler] ++ Mix.compilers(),
      compilers: Mix.compilers(),
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  defp rustler_crates do
    [
      nomure_native: [
        path: "native/nomure_native",
        mode: :release
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nomure.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:fdb, "~> 6.0.15-1"},
      {:ex_zstd, git: "https://github.com/WolfDan/ExZstd.git"},
      {:jason, "~> 1.1"},
      {:benchee, "~> 0.11", only: :dev},
      {:nimble_csv, "~> 0.5.0", only: [:dev, :test]},
      {:msgpax, "~> 2.2"},
      {:rustler, "~> 0.19.0"}
    ]
  end
end
