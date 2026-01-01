defmodule LiveStyle.Compiler.Class.DeclarationMerger do
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

  alias LiveStyle.Compiler.Class.Conditional

  @doc """
  Merges a property value into an accumulator.

  ## Parameters

    * `acc` - Current accumulator list of {prop, value} tuples
    * `prop` - Property name (atom)
    * `value` - New value to merge

  ## Returns

  Updated accumulator with merged property.
  """
  @spec merge(list(), atom(), term()) :: list()
  def merge(acc, prop, value) do
    existing = get_prop(acc, prop)

    cond do
      existing == nil ->
        put_prop(acc, prop, value)

      Conditional.conditional?(existing) and Conditional.conditional?(value) ->
        # Both conditional: merge lists and sort
        merged = merge_lists(to_list(existing), to_list(value))
        put_prop(acc, prop, sort_list(merged))

      Conditional.conditional?(existing) ->
        # Existing conditional, new simple: simple becomes :default
        merged = put_key(to_list(existing), :default, value)
        put_prop(acc, prop, sort_list(merged))

      Conditional.conditional?(value) ->
        # Existing simple, new conditional: existing becomes :default if not set
        merged = put_new_key(to_list(value), :default, existing)
        put_prop(acc, prop, sort_list(merged))

      true ->
        # Both simple: last wins
        put_prop(acc, prop, value)
    end
  end

  defp get_prop(acc, prop) do
    case List.keyfind(acc, prop, 0) do
      {^prop, value} -> value
      nil -> nil
    end
  end

  defp put_prop(acc, prop, value) do
    List.keystore(acc, prop, 0, {prop, value})
  end

  # Conditional values should already be lists
  defp to_list(value) when is_list(value), do: value

  # Merge two lists, later values override earlier ones
  defp merge_lists(list1, list2) do
    # Start with list1, then apply all updates from list2
    Enum.reduce(list2, list1, fn {key, value}, acc ->
      put_key(acc, key, value)
    end)
  end

  # Put a key in a list (replaces existing or appends)
  defp put_key(list, key, value) do
    case List.keyfind(list, key, 0) do
      nil -> [{key, value} | list]
      _ -> List.keyreplace(list, key, 0, {key, value})
    end
  end

  # Put a key only if it doesn't exist
  defp put_new_key(list, key, value) do
    case List.keyfind(list, key, 0) do
      nil -> [{key, value} | list]
      _ -> list
    end
  end

  # Sort list by key for deterministic iteration
  defp sort_list(list) do
    Enum.sort_by(list, fn {k, _v} -> to_string(k) end)
  end
end
