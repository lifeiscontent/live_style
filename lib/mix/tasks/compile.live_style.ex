defmodule Mix.Tasks.Compile.LiveStyle do
  @moduledoc """
  Mix compiler that generates CSS from LiveStyle definitions.

  This compiler runs after the standard Elixir compiler and generates
  the CSS file from the manifest that was populated during compilation.

  ## Installation

  Add to your `mix.exs`:

      def project do
        [
          compilers: Mix.compilers() ++ [:live_style],
          # ...
        ]
      end

  ## Configuration

  Configure in your `config/config.exs`:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## What It Does

  1. Writes the generated CSS to the configured output path
  2. Reports statistics (vars, keyframes, rules)

  ## Output

  The compiler outputs a message like:

      LiveStyle: 42 vars, 3 keyframes, 128 rules → priv/static/assets/live.css

  ## Related Tasks

  - `mix live_style.gen.css` - Force regenerate CSS with recompilation
  - `mix live_style default` - Run with profile configuration
  """

  use Mix.Task.Compiler

  alias LiveStyle.Compiler.Writer

  @impl true
  def run(_args) do
    case Writer.write_css(log: &log_write/1) do
      :ok -> {:ok, []}
      {:error, reason} -> {:error, [reason]}
    end
  end

  defp log_write({:written, stats, output_path}) do
    Mix.shell().info([
      :green,
      "LiveStyle: ",
      :reset,
      "#{stats.vars} vars, #{stats.keyframes} keyframes, #{stats.classes} rules → ",
      :cyan,
      output_path
    ])
  end

  @impl true
  def manifests do
    [LiveStyle.Storage.path()]
  end

  @impl true
  def clean do
    File.rm(LiveStyle.Storage.path())
    File.rm(LiveStyle.Config.output_path())
    :ok
  end
end
