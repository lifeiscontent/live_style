defmodule Mix.Tasks.LiveStyle.Gen.Css do
  @moduledoc """
  Generates the LiveStyle CSS file with a forced recompilation.

  This task clears the manifest, forces a recompilation of all modules,
  and generates fresh CSS. Use this when you need to ensure the CSS is
  fully regenerated from scratch.

  For regular development, the LiveStyle compiler (`mix compile`) or the
  watcher (in `config/dev.exs`) handles CSS generation automatically.

  ## Usage

      mix live_style.gen.css

  ## Options

  - `--output`, `-o` - Output file path (overrides configured `output_path`)

  ## Examples

      # Generate CSS to default location
      mix live_style.gen.css

      # Generate to custom location
      mix live_style.gen.css -o assets/css/styles.css

  ## When to Use

  Use this task when:
  - Setting up LiveStyle for the first time
  - CSS appears stale or incorrect
  - Debugging CSS generation issues
  - Building for production (though `mix compile` usually suffices)

  ## Configuration

  Configure the default output path in your `config/config.exs`:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Integration

  Add the generated CSS to your root layout:

      <link rel="stylesheet" href={~p"/assets/live.css"} />
  """

  use Mix.Task

  alias LiveStyle.Compiler.CSS

  @shortdoc "Generates CSS from LiveStyle definitions"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [output: :string],
        aliases: [o: :output]
      )

    output_path = Keyword.get_lazy(opts, :output, &LiveStyle.Config.output_path/0)

    # Clear storage and recompile
    LiveStyle.Storage.clear()
    Mix.Task.run("compile", ["--force"])

    # Read manifest and generate CSS
    manifest = LiveStyle.Storage.read()
    css = CSS.compile(manifest)

    # Add stats header
    stats = collect_stats(manifest)
    css_with_header = "/* LiveStyle: #{stats} */\n\n#{css}"

    # Write file
    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(output_path, css_with_header)

    # Output summary
    Mix.shell().info([
      :green,
      "Generated LiveStyle CSS: ",
      :cyan,
      "#{stats}",
      :reset,
      " -> ",
      :yellow,
      output_path
    ])
  end

  defp collect_stats(manifest) do
    vars_count = map_size(manifest.vars)
    consts_count = map_size(manifest.consts)
    keyframes_count = map_size(manifest.keyframes)
    classes_count = map_size(manifest.classes)
    themes_count = map_size(manifest.themes)
    vt_count = map_size(manifest.view_transitions)
    pt_count = map_size(manifest.position_try)

    [
      {vars_count, "vars"},
      {consts_count, "consts"},
      {keyframes_count, "keyframes"},
      {classes_count, "classes"},
      {themes_count, "themes"},
      {vt_count, "view transitions"},
      {pt_count, "position-try"}
    ]
    |> Enum.filter(fn {count, _} -> count > 0 end)
    |> Enum.map_join(", ", fn {count, label} -> "#{count} #{label}" end)
  end
end
