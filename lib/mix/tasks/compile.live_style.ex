defmodule Mix.Tasks.Compile.LiveStyle do
  @moduledoc """
  Mix compiler that merges LiveStyle module data after Elixir compilation.

  This compiler runs after the standard Elixir compiler and merges all
  per-module data files into the manifest. It does NOT generate CSS -
  that's handled by the watcher (in development) or `mix live_style`
  command (in production builds), matching the esbuild/tailwind pattern.

  ## Installation

  Add to your `mix.exs`:

      def project do
        [
          compilers: Mix.compilers() ++ [:live_style],
          # ...
        ]
      end

  ## Configuration

  Configure the profile in your `config/config.exs`:

      config :live_style,
        default: [
          output: "priv/static/assets/css/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Development Setup

  Add the watcher to your endpoint in `config/dev.exs` (like esbuild/tailwind):

      watchers: [
        live_style: {LiveStyle, :install_and_run, [:default, ~w(--watch)]}
      ]

  ## Production Build

  In your deployment scripts, run:

      mix live_style default

  ## What This Compiler Does

  Merges per-module data files into the manifest. CSS generation is
  handled separately by the watcher or `mix live_style` command.

  ## Related Tasks

  - `mix live_style <profile>` - Generate CSS (use in production builds)
  - `mix live_style <profile> --watch` - Watch mode for development
  """

  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    # Merge all per-module files into the manifest
    # This is done here (after all modules compiled) to avoid lock contention
    module_count = LiveStyle.Storage.merge_module_data()

    if module_count == 0 do
      Mix.shell().info([
        :yellow,
        "LiveStyle: ",
        :reset,
        "No modules found with LiveStyle definitions"
      ])
    end

    # CSS generation is handled by:
    # - In development: the watcher configured in endpoint (like esbuild/tailwind)
    # - In production: `mix live_style <profile>` in build scripts
    #
    # This compiler only merges data, matching the esbuild/tailwind pattern
    # where the watcher/command handles asset generation, not a Mix compiler.
    {:ok, []}
  end

  @impl true
  def manifests do
    [LiveStyle.Storage.path(), LiveStyle.Storage.usage_path()]
  end

  @impl true
  def clean do
    File.rm(LiveStyle.Storage.path())
    File.rm(LiveStyle.Storage.usage_path())

    if path = LiveStyle.Config.output_path() do
      File.rm(path)
    end

    :ok
  end
end
