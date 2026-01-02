defmodule LiveStyle.Class.DeclarationMerger do
  @moduledoc """
  Merges CSS declarations with conditional value handling.

  This module handles the merging of property values following StyleX semantics:
  - Simple values override previous values
  - Conditional values (lists with `:default`, pseudo-classes, media queries) merge
  - Mixed simple/conditional values integrate properly

  ## Merge Semantics

  1. **Simple + Simple**: Last value wins
  2. **Conditional + Conditional**: Lists are merged (keys combined)
  3. **Simple + Conditional**: Simple becomes the `:default` of existing conditions
  4. **Conditional + Simple**: New simple overwrites `:default`, conditions preserved
  """

  alias LiveStyle.Class.Conditional
  alias LiveStyle.Utils

  @doc """
  Merges a property value into an accumulator.

  The accumulator is a tuple list where keys can be atoms (CSS property names)
  or strings (CSS custom properties via `var()`). Conditional values also use
  tuple lists since their keys can be atoms, strings, or complex terms.

  ## Parameters

    * `acc` - Current accumulator (list of {prop, value} tuples)
    * `prop` - Property name (atom or string for custom properties)
    * `value` - New value to merge

  ## Returns

  Updated accumulator with merged property.
  """
  @spec merge(list(), atom() | String.t(), term()) :: list()
  def merge(acc, prop, value) do
    existing = Utils.tuple_get(acc, prop)

    cond do
      existing == nil ->
        Utils.tuple_put(acc, prop, value)

      Conditional.conditional?(existing) and Conditional.conditional?(value) ->
        # Both conditional: merge lists and sort
        merged = Utils.tuple_merge(to_list(existing), to_list(value))
        Utils.tuple_put(acc, prop, Utils.tuple_sort_by_key(merged))

      Conditional.conditional?(existing) ->
        # Existing conditional, new simple: simple becomes :default
        merged = Utils.tuple_put(to_list(existing), :default, value)
        Utils.tuple_put(acc, prop, Utils.tuple_sort_by_key(merged))

      Conditional.conditional?(value) ->
        # Existing simple, new conditional: existing becomes :default if not set
        merged = Utils.tuple_put_new(to_list(value), :default, existing)
        Utils.tuple_put(acc, prop, Utils.tuple_sort_by_key(merged))

      true ->
        # Both simple: last wins
        Utils.tuple_put(acc, prop, value)
    end
  end

  # Conditional values should already be lists
  defp to_list(value) when is_list(value), do: value
end
