defmodule LiveStyle.Compiler.CSS.Writer.Stats do
  @moduledoc false

  @spec comment(LiveStyle.Manifest.t()) :: String.t()
  def comment(manifest) do
    vars_count = map_size(manifest.vars)
    keyframes_count = map_size(manifest.keyframes)
    classes_count = map_size(manifest.classes)
    themes_count = map_size(manifest.themes)

    "/* LiveStyle: #{vars_count} vars, #{keyframes_count} keyframes, #{classes_count} classes, #{themes_count} themes */"
  end
end
