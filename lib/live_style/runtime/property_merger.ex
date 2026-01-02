defmodule LiveStyle.Runtime.PropertyMerger do
  @moduledoc """
  Merges property classes with last-wins semantics.

  This module handles the StyleX-compatible merging behavior where:
  - Later values override earlier ones for the same property
  - `:__unset__` removes a property from the accumulator

  ## Merge Semantics

  Property classes follow StyleX's merging rules:
  1. Each CSS property is tracked independently
  2. The last class for a property wins
  3. `:__unset__` explicitly removes a property
  """

  @type prop_classes :: [{atom() | String.t(), String.t() | :__unset__}]
  @type accumulator :: [{atom() | String.t(), String.t() | :__unset__}]

  @doc """
  Merges property classes into an accumulator.

  ## Parameters

    * `prop_classes` - List of {property, class_string} tuples (or :__unset__)
    * `acc` - Current accumulator

  ## Returns

  Updated accumulator with merged classes.
  """
  @spec merge(prop_classes(), accumulator()) :: accumulator()
  def merge(prop_classes, acc) when is_list(prop_classes) do
    Enum.reduce(prop_classes, acc, &merge_prop/2)
  end

  @doc """
  Merges a single property class into the accumulator.
  """
  @spec merge_prop({atom() | String.t(), String.t() | :__unset__}, accumulator()) :: accumulator()
  def merge_prop({prop, :__unset__}, acc), do: List.keydelete(acc, prop, 0)
  def merge_prop({prop, class}, acc), do: List.keystore(acc, prop, 0, {prop, class})

  @doc """
  Extracts the final class list from the accumulator.

  Filters out :__unset__ and nil values.
  """
  @spec to_class_list(accumulator()) :: [String.t()]
  def to_class_list(acc) do
    acc
    |> Enum.map(fn {_key, value} -> value end)
    |> Enum.reject(&(&1 == :__unset__ or &1 == nil or &1 == ""))
  end
end
