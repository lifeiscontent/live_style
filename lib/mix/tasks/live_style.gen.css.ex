defmodule Mix.Tasks.LiveStyle.Gen.Css do
  @moduledoc """
  Generates the LiveStyle CSS file from the compile-time manifest.

  This task reads CSS rules and variables collected during compilation
  and outputs them to a CSS file.

  ## Usage

      mix live_style.gen.css

  ## Options

      --output, -o  Output file path (default: uses configured output_path)

  ## Example

      # Generate CSS to default location
      mix live_style.gen.css

      # Generate to custom location
      mix live_style.gen.css -o assets/css/styles.css

  ## Configuration

  The default output path can be configured in `config/config.exs`:

      config :live_style, output_path: "priv/static/assets/live.css"

  ## Integration

  Add the generated CSS to your root layout:

      <link rel="stylesheet" href={~p"/assets/live.css"} />
  """

  use Mix.Task

  @shortdoc "Generates CSS from LiveStyle definitions"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [output: :string],
        aliases: [o: :output]
      )

    output_path = Keyword.get_lazy(opts, :output, &LiveStyle.output_path/0)

    LiveStyle.clear()
    Mix.Task.run("compile", ["--force"])

    css = LiveStyle.get_all_css()

    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(output_path, css)

    manifest = LiveStyle.read_manifest()
    var_count = map_size(manifest[:vars] || %{})
    keyframe_count = map_size(manifest[:keyframes] || %{})
    rule_count = map_size(manifest[:rules] || %{})

    Mix.shell().info([
      :green,
      "Generated LiveStyle CSS: ",
      :cyan,
      "#{var_count}",
      :reset,
      " variables, ",
      :cyan,
      "#{keyframe_count}",
      :reset,
      " keyframes, ",
      :cyan,
      "#{rule_count}",
      :reset,
      " rules -> ",
      :yellow,
      output_path
    ])
  end
end
