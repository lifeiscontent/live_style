defmodule Mix.Tasks.LiveStyle.Gen.Css do
  @moduledoc """
  Generates the LiveStyle CSS file from the compile-time manifest.

  This task forces a recompilation and generates CSS. For regular usage,
  prefer `mix live_style default` which uses the profile configuration.

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

  Configure in your `config/config.exs`:

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

  @shortdoc "Generates CSS from LiveStyle definitions"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [output: :string],
        aliases: [o: :output]
      )

    output_path = Keyword.get_lazy(opts, :output, &LiveStyle.output_path/0)

    # Clear storage and recompile
    LiveStyle.Storage.clear()
    Mix.Task.run("compile", ["--force"])

    # Read manifest and generate CSS
    manifest = LiveStyle.Storage.read()
    css = LiveStyle.CSS.generate(manifest)

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
    rules_count = map_size(manifest.rules)
    themes_count = map_size(manifest.themes)
    vt_count = map_size(manifest.view_transitions)
    pt_count = map_size(manifest.position_try)

    parts =
      [
        {vars_count, "vars"},
        {consts_count, "consts"},
        {keyframes_count, "keyframes"},
        {rules_count, "rules"},
        {themes_count, "themes"},
        {vt_count, "view transitions"},
        {pt_count, "position-try"}
      ]
      |> Enum.filter(fn {count, _} -> count > 0 end)
      |> Enum.map(fn {count, label} -> "#{count} #{label}" end)

    Enum.join(parts, ", ")
  end
end
