defmodule Entangle.MixProject do
  use Mix.Project

  def project do
    [
      app: :entangle,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:option, git: "https://github.com/nanaki04/option_ex.git"},
      {:result, git: "https://github.com/nanaki04/result_ex.git"},
      {:layers, git: "https://github.com/nanaki04/layers_ex.git"}
    ]
  end
end
