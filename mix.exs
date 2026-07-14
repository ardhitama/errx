defmodule Errx.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://github.com/ardhitama/errx"

  def project do
    [
      app: :errx,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Errx",
      source_url: @source_url,
      docs: docs(),
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: [quality: :test, credo: :test]]
  end

  def application, do: []

  defp deps do
    [
      {:ex_doc, ">= 0.34.0 and < 0.41.0", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Contextual error tuples with caller locations, metadata, and cause chains."
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["GPL-3.0-only"],
      maintainers: ["ardhitama"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp aliases do
    [
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "hex.build"
      ]
    ]
  end
end
