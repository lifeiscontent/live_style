defmodule LiveStyle.MixProject do
  use Mix.Project

  @version "0.4.1"
  @source_url "https://github.com/lifeiscontent/live_style"

  def project do
    [
      app: :live_style,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "LiveStyle",
      description: "Atomic CSS-in-Elixir for Phoenix LiveView, inspired by StyleX",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0", optional: true},
      {:file_system, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Aaron Buckley"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "LiveStyle",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end
end
