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
  @pseudo_element_map %{
    group: "view-transition-group",
    image_pair: "view-transition-image-pair",
    old: "view-transition-old",
    new: "view-transition-new"
  }

  # String keys map to their snake_case atom equivalents
  @string_to_atom_keys %{
    "group" => :group,
    "image-pair" => :image_pair,
    "old" => :old,
    "new" => :new
  }

  @doc """
  Generates all view transition CSS rules from the manifest.

  Returns a string containing all view transition rules, or an empty string
  if there are no view transition entries.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.view_transitions
    |> Enum.sort_by(fn {_key, entry} -> entry.ident end)
    |> Enum.map_join("\n", fn {_key, entry} ->
      generate_entry(entry)
    end)
  end

  # Generate CSS for a single view transition entry
  # All pseudo-elements for one view transition on a single line
  # Ordering for deterministic output: group, image_pair, new, old
  @pseudo_sort_order %{group: 0, image_pair: 1, new: 2, old: 3}

  defp generate_entry(%{ident: ident, styles: styles}) do
    styles
    |> Enum.sort_by(fn {pseudo_key, _} ->
      normalized = Map.get(@string_to_atom_keys, pseudo_key, pseudo_key)
      {Map.get(@pseudo_sort_order, normalized, 99), to_string(pseudo_key)}
    end)
    |> Enum.map_join("", fn {pseudo_key, declarations} ->
      # Normalize string keys to atoms
      normalized_key = Map.get(@string_to_atom_keys, pseudo_key, pseudo_key)
      pseudo_element = Map.get(@pseudo_element_map, normalized_key, to_string(pseudo_key))
      selector = "::#{pseudo_element}(*.#{ident})"
      decl_str = Utils.format_declarations(declarations)
      "#{selector}{#{decl_str}}"
    end)
  end
end
