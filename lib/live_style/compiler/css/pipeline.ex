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
  Generates CSS content from the manifest.

  ## Options

    * `:manifest` - Use a specific manifest (default: reads from storage)
    * `:stats` - Include stats comment header (default: true)

  ## Returns

  The complete CSS string ready to be written to a file.
  """
  @spec generate(keyword()) :: String.t()
  def generate(opts \\ []) do
    manifest = Keyword.get_lazy(opts, :manifest, &Storage.read/0)
    include_stats = Keyword.get(opts, :stats, true)

    css = CSS.compile(manifest)

    if include_stats do
      Stats.comment(manifest) <> "\n\n" <> css
    else
      css
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
