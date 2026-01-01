defmodule LiveStyle.Runtime.PropertyMerger do
  @moduledoc """
  Merges property classes with last-wins semantics.

  This module handles the StyleX-compatible merging behavior where:
  - Later values override earlier ones for the same property
  - `:__unset__` removes a property from the accumulator
  - Dynamic classes are tracked separately with unique keys

  ## Merge Semantics

  Property classes follow StyleX's merging rules:
  1. Each CSS property is tracked independently
  2. The last class for a property wins
  3. `:__unset__` explicitly removes a property
  """

  @type prop_classes :: %{atom() => String.t() | :__unset__}
  @type dynamic_key :: {:__dynamic__, integer()}
  @type accumulator :: %{(atom() | dynamic_key()) => String.t() | :__unset__}

  @doc """
  Merges property classes into an accumulator.

  ## Parameters

    * `prop_classes` - Map of property to class string (or :__unset__)
    * `acc` - Current accumulator

  ## Returns

  Updated accumulator with merged classes.
  """
  @spec merge(prop_classes(), accumulator()) :: accumulator()
  def merge(prop_classes, acc) when is_map(prop_classes) do
    Enum.reduce(prop_classes, acc, &merge_prop/2)
  end

  @doc """
  Merges a single property class into the accumulator.
  """
  @spec merge_prop({atom(), String.t() | :__unset__}, accumulator()) :: accumulator()
  def merge_prop({prop, :__unset__}, acc), do: Map.delete(acc, prop)
  def merge_prop({prop, class}, acc), do: Map.put(acc, prop, class)

  @doc """
  Adds a dynamic class to the accumulator with a unique key.

  Dynamic classes don't merge by property - each one is tracked separately.
  Uses a tagged tuple key `{:__dynamic__, id}` instead of magic strings.
  """
  @spec add_dynamic(String.t(), accumulator()) :: accumulator()
  def add_dynamic(class_string, acc) do
    dyn_key = {:__dynamic__, :erlang.unique_integer([:positive])}
    Map.put(acc, dyn_key, class_string)
  end

  @doc """
  Extracts the final class list from the accumulator.

  Filters out :__unset__ and nil values.
  """
  @spec to_class_list(accumulator()) :: [String.t()]
  def to_class_list(acc) do
    acc
    |> Map.values()
    |> Enum.reject(&(&1 == :__unset__ or &1 == nil or &1 == ""))
  end
end
