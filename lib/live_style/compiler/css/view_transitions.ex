defmodule LiveStyle.Compiler.CSS.ViewTransitions do
  @moduledoc """
  Generates CSS view transition rules from the manifest.

  This module handles generation of `::view-transition-*` pseudo-element rules
  for the View Transitions API.

  ## Supported Pseudo-Elements

  - `::view-transition-group(*.name)` - The group container
  - `::view-transition-image-pair(*.name)` - Container for old/new images
  - `::view-transition-old(*.name)` - The outgoing snapshot
  - `::view-transition-new(*.name)` - The incoming snapshot

  ## Output Format

  Generates minified CSS in StyleX format:
  ```css
  ::view-transition-old(*.fade){animation-duration:.5s}::view-transition-new(*.fade){...}
  ```
  """

  alias LiveStyle.Utils

  # Map view transition keys (snake_case atoms) to CSS pseudo-elements
  @pseudo_element_map [
    group: "view-transition-group",
    image_pair: "view-transition-image-pair",
    old: "view-transition-old",
    new: "view-transition-new"
  ]

  # String keys map to their snake_case atom equivalents
  defp normalize_pseudo_key("group"), do: :group
  defp normalize_pseudo_key("image-pair"), do: :image_pair
  defp normalize_pseudo_key("old"), do: :old
  defp normalize_pseudo_key("new"), do: :new
  defp normalize_pseudo_key(key), do: key

  @doc """
  Generates all view transition CSS rules from the manifest.

  Returns a string containing all view transition rules, or an empty string
  if there are no view transition entries.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.view_transitions
    |> Enum.sort_by(fn {_key, entry} -> Keyword.fetch!(entry, :ident) end)
    |> Enum.map_join("\n", fn {_key, entry} ->
      generate_entry(entry)
    end)
  end

  # Generate CSS for a single view transition entry
  # All pseudo-elements for one view transition on a single line
  # Sort by pseudo-element for deterministic output across Elixir/OTP versions
  defp generate_entry(entry) do
    ident = Keyword.fetch!(entry, :ident)
    styles = Keyword.fetch!(entry, :styles)

    styles
    # Sort by pseudo key for deterministic iteration order
    |> Enum.sort_by(fn {pseudo_key, _} -> pseudo_sort_order(pseudo_key) end)
    |> Enum.map_join("", fn {pseudo_key, declarations} ->
      # Normalize string keys to atoms
      normalized_key = normalize_pseudo_key(pseudo_key)
      pseudo_element = Keyword.get(@pseudo_element_map, normalized_key, to_string(pseudo_key))
      selector = "::#{pseudo_element}(*.#{ident})"
      # Sort declarations for deterministic output
      decl_str = Utils.format_declarations(declarations, sort: true)
      "#{selector}{#{decl_str}}"
    end)
  end

  # Sort order for view transition pseudo-elements (group, image_pair, old, new)
  defp pseudo_sort_order(:group), do: 0
  defp pseudo_sort_order("group"), do: 0
  defp pseudo_sort_order(:image_pair), do: 1
  defp pseudo_sort_order("image-pair"), do: 1
  defp pseudo_sort_order(:old), do: 2
  defp pseudo_sort_order("old"), do: 2
  defp pseudo_sort_order(:new), do: 3
  defp pseudo_sort_order("new"), do: 3
  defp pseudo_sort_order(other), do: {4, to_string(other)}
end
