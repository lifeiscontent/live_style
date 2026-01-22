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
          output: "priv/static/assets/css/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## What It Does

  1. Writes the generated CSS to the configured output path
  2. Reports statistics (vars, keyframes, rules)

  ## Output

  The compiler outputs a message like:

      LiveStyle: 42 vars, 3 keyframes, 128 rules → priv/static/assets/css/live.css

  ## Related Tasks

  - `mix live_style.gen.css` - Force regenerate CSS with recompilation
  - `mix live_style default` - Run with profile configuration
  """

  use Mix.Task.Compiler

  alias LiveStyle.Compiler.Writer

  @impl true
  def run(_args) do
    # Check if manifest is empty/missing - if so, we need to force recompilation
    # of modules that use LiveStyle to repopulate it
    manifest = LiveStyle.Storage.read()

    # Note: We don't clear usage on --force because this task runs AFTER the
    # elixir compiler. Usage has already been re-recorded during elixir compile.
    # Use `mix clean` or `mix compile.live_style --clean` to clear usage.

    if manifest_empty?(manifest) and not recompiling?() do
      # Manifest is empty but modules exist - need to recompile
      # Set flag to prevent infinite loop, then rerun elixir compiler
      Process.put(:live_style_recompiling, true)

      Mix.shell().info([
        :yellow,
        "LiveStyle: ",
        :reset,
        "manifest empty, forcing recompilation..."
      ])

      # Force recompile by running mix compile with --force
      Mix.Task.rerun("compile.elixir", ["--force"])

      # Now write CSS with the repopulated manifest
      case Writer.write_css(log: &log_write/1) do
        :ok -> {:ok, []}
        {:error, reason} -> {:error, [reason]}
      end
    else
      case Writer.write_css(log: &log_write/1) do
        :ok -> {:ok, []}
        {:error, reason} -> {:error, [reason]}
      end
    end
  end

  defp manifest_empty?(manifest) do
    manifest.vars == [] and
      manifest.consts == [] and
      manifest.keyframes == [] and
      manifest.position_try == [] and
      manifest.view_transition_classes == [] and
      manifest.classes == [] and
      manifest.theme_classes == []
  end

  defp recompiling? do
    Process.get(:live_style_recompiling, false)
  end

  defp log_write({:written, stats, output_path}) do
    Mix.shell().info([
      :green,
      "LiveStyle: ",
      :reset,
      "#{stats[:vars]} vars, #{stats[:keyframes]} keyframes, #{stats[:classes]} rules → ",
      :cyan,
      output_path
    ])
  end

  defp log_write({:unchanged, _output_path}) do
    # CSS unchanged, no need to log during compilation
    :ok
  end

  @impl true
  def manifests do
    [LiveStyle.Storage.path(), LiveStyle.Storage.usage_path()]
  end

  @impl true
  def clean do
    File.rm(LiveStyle.Storage.path())
    File.rm(LiveStyle.Storage.usage_path())
    File.rm(LiveStyle.Config.output_path())
    :ok
  end
end
