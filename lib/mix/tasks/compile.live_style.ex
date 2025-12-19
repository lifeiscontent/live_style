defmodule Mix.Tasks.Compile.LiveStyle do
  @moduledoc """
  Mix compiler that generates CSS from LiveStyle definitions.

  Add to your mix.exs:

      def project do
        [
          compilers: Mix.compilers() ++ [:live_style],
          # ...
        ]
      end

  This compiler runs after the standard Elixir compiler and generates
  the CSS file from the manifest that was populated during compilation.

  ## Configuration

  Configure in your `config/config.exs`:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]
  """

  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    LiveStyle.Compiler.validate_var_references!()

    case LiveStyle.Compiler.write_css(log: &log_write/1) do
      :ok -> {:ok, []}
      {:error, reason} -> {:error, [reason]}
    end
  end

  defp log_write({:written, var_count, keyframe_count, rule_count, output_path}) do
    Mix.shell().info([
      :green,
      "LiveStyle: ",
      :reset,
      "#{var_count} vars, #{keyframe_count} keyframes, #{rule_count} rules → ",
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
