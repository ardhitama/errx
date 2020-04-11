defmodule Errx.MixProject do
  use Mix.Project

  def project do
    [
      app: :errx,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Initially build to reduce the author's pain point when using erlang tuple style error handling where it has no information of who create the error tuple."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["GNU GPL V3"],
      links: %{"GitHub" => "https://github.com/ardhitama/errx"}
    ]
  end
end
