defmodule LiveStyle.Compiler.CSS.Pipeline do
  @moduledoc """
  CSS generation pipeline.

  This module orchestrates the transformation from manifest to final CSS output,
  including optional stats header.

  ## Pipeline Stages

  1. Read manifest from storage
  2. Generate CSS via formatters
  3. Optionally prepend stats comment

  ## Usage

      # Generate CSS from current manifest
      css = LiveStyle.Compiler.CSS.Pipeline.generate()

      # Generate without stats
      css = LiveStyle.Compiler.CSS.Pipeline.generate(stats: false)

      # Generate from specific manifest
      css = LiveStyle.Compiler.CSS.Pipeline.generate(manifest: my_manifest)
  """

  alias LiveStyle.Compiler.CSS
  alias LiveStyle.Compiler.CSS.Writer.Stats
  alias LiveStyle.Storage

  @doc """
  Generates CSS content from the manifest, optionally injecting into an input file.

  ## Options

    * `:manifest` - Use a specific manifest (default: reads from storage)
    * `:stats` - Include stats comment header (default: true)
    * `:input` - Optional input file path with `@import "live_style"` directive

  When `:input` option is provided, reads the input file and replaces
  `@import "live_style"` with the generated CSS.

  ## Returns

  The complete CSS string ready to be written to a file.
  """
  @spec generate(keyword()) :: String.t()
  def generate(opts \\ []) do
    manifest = Keyword.get_lazy(opts, :manifest, &Storage.read/0)
    include_stats = Keyword.get(opts, :stats, true)
    input_path = Keyword.get(opts, :input)

    css = CSS.compile(manifest)

    css =
      if include_stats do
        Stats.comment(manifest) <> "\n\n" <> css
      else
        css
      end

    case input_path do
      nil -> css
      path -> inject_into_input(path, css)
    end
  end

  @import_pattern ~r/@import\s+["']live_style["']\s*;?/

  defp inject_into_input(path, css) do
    input = File.read!(path)

    case Regex.split(@import_pattern, input, parts: 2) do
      [before, after_import] ->
        before <> css <> after_import

      [_no_match] ->
        raise ArgumentError, """
        Could not find @import "live_style" directive in #{path}.

        Add this line where you want LiveStyle CSS to be injected:

            @import "live_style";
        """
    end
  end

  @doc """
  Returns statistics about the manifest.

  Useful for logging after CSS generation.
  """
  @spec stats(LiveStyle.Manifest.t()) :: keyword()
  def stats(manifest) do
    [
      vars: length(manifest.vars),
      keyframes: length(manifest.keyframes),
      classes: length(manifest.classes),
      theme_classes: length(manifest.theme_classes),
      position_try: length(manifest.position_try),
      view_transition_classes: length(manifest.view_transition_classes)
    ]
  end
end
