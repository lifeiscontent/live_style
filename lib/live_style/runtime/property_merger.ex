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

  StyleX-compatible behavior: each property key is completely independent.
  Only exact key matches conflict - "color" and "color::default" are separate keys.
  """
  @spec merge_prop({atom() | String.t(), String.t() | :__unset__}, accumulator()) :: accumulator()
  def merge_prop({prop, :__unset__}, acc) do
    # StyleX behavior: :__unset__ (null) only removes the exact key
    normalized = normalize_key(prop)
    Enum.reject(acc, fn {k, _v} -> normalize_key(k) == normalized end)
  end

  def merge_prop({prop, class}, acc) do
    # StyleX behavior: only replace the exact same key
    normalized = normalize_key(prop)
    cleaned_acc = Enum.reject(acc, fn {k, _v} -> normalize_key(k) == normalized end)
    [{prop, class} | cleaned_acc]
  end

  # Normalize key for comparison (atom/string equivalence)
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key

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
