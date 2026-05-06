defmodule LiveStyle.MixProject do
  use Mix.Project

  @version "0.16.2"
  @source_url "https://github.com/lifeiscontent/live_style"
  @docs_modules [
    LiveStyle,
    LiveStyle.Attrs,
    LiveStyle.Compiler,
    LiveStyle.Config,
    LiveStyle.Dev,
    LiveStyle.Marker,
    LiveStyle.ShorthandBehavior,
    LiveStyle.ShorthandBehavior.AcceptShorthands,
    LiveStyle.ShorthandBehavior.FlattenShorthands,
    LiveStyle.ShorthandBehavior.ForbidShorthands,
    LiveStyle.Types,
    LiveStyle.When,
    Mix.Tasks.Compile.LiveStyle,
    Mix.Tasks.LiveStyle,
    Mix.Tasks.LiveStyle.Audit,
    Mix.Tasks.LiveStyle.Inspect,
    Mix.Tasks.LiveStyle.SetupTests
  ]
  @docs_skip_autolinks [
    "LiveStyle.CSSValue",
    "LiveStyle.Compiler.CSS",
    "LiveStyle.Data",
    "LiveStyle.PropertyMetadata",
    "LiveStyle.Registry",
    "LiveStyle.Storage",
    "LiveStyle.Value",
    "Mix.Tasks.Compile.LiveStyle",
    "live_style.audit",
    "live_style.inspect",
    "mix live_style.audit",
    "mix live_style.inspect"
  ]

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
      {:phoenix_live_view, "~> 1.1", optional: true, runtime: false},
      {:phoenix_html, "~> 3.3 or ~> 4.0", optional: true, runtime: false},
      {:file_system, "~> 1.0", optional: true, runtime: false},
      {:jason, "~> 1.4", runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:git_ops, "~> 2.10", only: :dev, runtime: false}
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
      groups_for_modules: [
        {"Core", [LiveStyle, LiveStyle.Attrs]},
        {"Advanced Helpers", [LiveStyle.Marker, LiveStyle.Types, LiveStyle.When]},
        {"Configuration", [LiveStyle.Config, LiveStyle.ShorthandBehavior]},
        {"Shorthand Behaviors",
         [
           LiveStyle.ShorthandBehavior.AcceptShorthands,
           LiveStyle.ShorthandBehavior.FlattenShorthands,
           LiveStyle.ShorthandBehavior.ForbidShorthands
         ]},
        {"Developer Tools", [LiveStyle.Compiler, LiveStyle.Dev]}
      ],
      filter_modules: fn module, _metadata -> module in @docs_modules end,
      skip_code_autolink_to: fn reference -> reference in @docs_skip_autolinks end,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit, :jason, :phoenix_html]
    ]
  end
end
