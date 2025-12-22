defmodule LiveStyle.CSS.AtomicRules do
  @moduledoc """
  Generates atomic CSS rules from the manifest's class entries.

  This module handles the generation of the main CSS rules for atomic classes,
  including:
  - LTR and RTL rule generation
  - CSS layer wrapping (optional, matching StyleX's `useLayers` option)
  - Selector building with specificity bumping
  - Fallback value processing
  - Selector prefixing (e.g., `::thumb`, `::placeholder`)

  ## Configuration

  Behavior is controlled by `LiveStyle.Config`:
  - `use_css_layers: true` - Group rules by priority in `@layer priorityN` blocks (StyleX `useLayers: true`)
  - `use_css_layers: false` (default) - Use `:not(#\\#)` selector hack (StyleX default)
  """

  alias LiveStyle.CSS.AtomicRules.Collector
  alias LiveStyle.CSS.AtomicRules.Renderer

  @doc """
  Generates all CSS rules from the manifest.

  Returns a string containing all atomic CSS rules, wrapped in layers if configured.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest
    |> Collector.collect()
    |> Renderer.render()
  end
end
