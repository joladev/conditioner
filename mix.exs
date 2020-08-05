defmodule Conditioner.MixProject do
  use Mix.Project

  def project do
    [
      app: :conditioner,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Conditioner.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 0.11.2"},
      {:telemetry, "~> 0.4"}
    ]
  end
end
