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

  Configure paths in your `config/config.exs`:

      config :live_style,
        output_path: "priv/static/assets/live.css",
        manifest_path: "_build/live_style_manifest.etf"
  """

  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    LiveStyle.validate_var_references!()
    manifest = LiveStyle.read_manifest()

    if has_styles?(manifest) do
      maybe_write_css(manifest)
    end

    {:ok, []}
  end

  defp has_styles?(manifest) do
    map_size(manifest[:rules] || %{}) > 0 or
      map_size(manifest[:vars] || %{}) > 0 or
      map_size(manifest[:keyframes] || %{}) > 0
  end

  defp maybe_write_css(manifest) do
    output_path = LiveStyle.output_path()
    css = LiveStyle.get_all_css()
    current_css = File.read(output_path) |> elem(1)

    if css != current_css do
      write_css(manifest, output_path, css)
    end
  end

  defp write_css(manifest, output_path, css) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, css)

    var_count = map_size(manifest[:vars] || %{})
    keyframe_count = map_size(manifest[:keyframes] || %{})
    rule_count = map_size(manifest[:rules] || %{})

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
    [LiveStyle.manifest_path()]
  end

  @impl true
  def clean do
    File.rm(LiveStyle.manifest_path())
    File.rm(LiveStyle.output_path())
    :ok
  end
end
