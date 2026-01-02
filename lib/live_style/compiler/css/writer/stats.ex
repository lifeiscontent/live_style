defmodule LiveStyle.Compiler.CSS.Writer.Stats do
  @moduledoc false

  @spec comment(LiveStyle.Manifest.t()) :: String.t()
  def comment(manifest) do
    vars_count = length(manifest.vars)
    keyframes_count = length(manifest.keyframes)
    classes_count = length(manifest.classes)
    themes_count = length(manifest.themes)

    "/* LiveStyle: #{vars_count} vars, #{keyframes_count} keyframes, #{classes_count} classes, #{themes_count} themes */"
  end
end
