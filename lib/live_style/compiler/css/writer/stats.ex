defmodule LiveStyle.Compiler.CSS.Writer.Stats do
  @moduledoc false

  @spec comment(LiveStyle.Manifest.t()) :: String.t()
  def comment(manifest) do
    vars_count = LiveStyle.Manifest.count(manifest, :vars)
    keyframes_count = LiveStyle.Manifest.count(manifest, :keyframes)
    classes_count = LiveStyle.Manifest.count(manifest, :classes)
    themes_count = LiveStyle.Manifest.count(manifest, :theme_classes)

    "/* LiveStyle: #{vars_count} vars, #{keyframes_count} keyframes, #{classes_count} classes, #{themes_count} themes */"
  end
end
