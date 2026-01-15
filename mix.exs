defmodule LiveStyle.MixProject do
  use Mix.Project

  @version "0.13.2"
  @source_url "https://github.com/lifeiscontent/live_style"

  def project do
    [
      app: :live_style,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      aliases: aliases(),
      name: "LiveStyle",
      description: "Atomic CSS-in-Elixir for Phoenix LiveView, inspired by StyleX",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  defp aliases do
    [
      # Pre-compile test files to ensure LiveStyle modules are in the manifest
      test: ["live_style.setup_tests", "test"],
      # Run all code quality checks before committing
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "docs",
        "cmd MIX_ENV=test mix test"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev, optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Aaron Reisman"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib data .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/design-tokens.md",
        "guides/styling-components.md",
        "guides/theming.md",
        "guides/advanced-features.md",
        "guides/configuration.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit]
    ]
  end
end
