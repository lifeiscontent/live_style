defmodule LiveStyle.Compiler.Class.DeclarationMerger do
  @moduledoc """
  Merges CSS declarations with conditional value handling.

  This module handles the merging of property values following StyleX semantics:
  - Simple values override previous values
  - Conditional values (maps with `:default`, pseudo-classes, media queries) merge
  - Mixed simple/conditional values integrate properly

  ## Merge Semantics

  1. **Simple + Simple**: Last value wins
  2. **Conditional + Conditional**: Maps are merged (keys combined)
  3. **Simple + Conditional**: Simple becomes the `:default` of existing conditions
  4. **Conditional + Simple**: New simple overwrites `:default`, conditions preserved
  """

  alias LiveStyle.Compiler.Class.Conditional

  @doc """
  Merges a property value into an accumulator.

  ## Parameters

    * `acc` - Current accumulator map
    * `prop` - Property name (atom)
    * `value` - New value to merge

  ## Returns

  Updated accumulator with merged property.
  """
  @spec merge(map(), atom(), term()) :: map()
  def merge(acc, prop, value) do
    existing = Map.get(acc, prop)

    cond do
      existing == nil ->
        Map.put(acc, prop, value)

      Conditional.conditional?(existing) and Conditional.conditional?(value) ->
        # Both conditional: merge the maps
        Map.put(
          acc,
          prop,
          Map.merge(
            LiveStyle.Utils.normalize_to_map(existing),
            LiveStyle.Utils.normalize_to_map(value)
          )
        )

      Conditional.conditional?(existing) ->
        # Existing conditional, new simple: simple becomes :default
        existing_map = LiveStyle.Utils.normalize_to_map(existing)
        Map.put(acc, prop, Map.put(existing_map, :default, value))

      Conditional.conditional?(value) ->
        # Existing simple, new conditional: existing becomes :default if not set
        new_map = LiveStyle.Utils.normalize_to_map(value)
        Map.put(acc, prop, Map.put_new(new_map, :default, existing))

      true ->
        # Both simple: last wins
        Map.put(acc, prop, value)
    end
  end
end
