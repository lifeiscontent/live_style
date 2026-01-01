defmodule LiveStyle.Compiler.Class.Conditional do
  @moduledoc false
  # Internal module for conditional value detection and flattening.
  #
  # A value is "conditional" if it represents a map of selectors to values,
  # like `%{:default => "red", ":hover" => "blue"}`.
  #
  # Detection rules:
  # 1. Has `:default` or `"default"` key → conditional
  # 2. All keys are selector strings (start with ":" or "@") → conditional
  # 3. Otherwise → not conditional

  @doc false
  @spec conditional?(term()) :: boolean()
  def conditional?(value) when is_map(value) do
    keys = Map.keys(value)
    has_default?(keys) or all_selector_keys?(keys)
  end

  def conditional?(value) when is_list(value) do
    # Handle both proper keyword lists and lists with mixed atom/string keys
    # (MediaQueryTransform can produce lists with string keys)
    case extract_keys(value) do
      {:ok, keys} -> has_default?(keys) or all_selector_keys?(keys)
      :error -> false
    end
  end

  def conditional?(_), do: false

  defp extract_keys(list) do
    keys =
      Enum.map(list, fn
        {key, _value} when is_atom(key) or is_binary(key) -> key
        _ -> throw(:not_key_value_list)
      end)

    {:ok, keys}
  catch
    :not_key_value_list -> :error
  end

  defp has_default?(keys) do
    :default in keys or "default" in keys
  end

  defp all_selector_keys?([]), do: false

  defp all_selector_keys?(keys) do
    Enum.all?(keys, &selector_key?/1)
  end

  @doc false
  @spec flatten(term(), String.t() | nil) :: [{String.t() | nil, term()}]
  # Values are pre-sorted at entry points for deterministic iteration
  def flatten(value_map, parent_selector) when is_map(value_map) do
    Enum.flat_map(value_map, fn {condition, value} ->
      current_selector = combine_selectors(parent_selector, condition)

      cond do
        is_map(value) and conditional?(value) ->
          flatten(value, current_selector)

        is_list(value) and conditional?(value) ->
          flatten(value, current_selector)

        true ->
          [{current_selector, value}]
      end
    end)
  end

  # Values are pre-sorted at entry points for deterministic iteration
  # Handle lists directly without converting to maps
  def flatten(value_list, parent_selector) when is_list(value_list) do
    if conditional?(value_list) do
      Enum.flat_map(value_list, &flatten_entry(&1, parent_selector))
    else
      [{parent_selector, value_list}]
    end
  end

  def flatten(value, parent_selector) do
    [{parent_selector, value}]
  end

  defp flatten_entry({condition, value}, parent_selector) do
    current_selector = combine_selectors(parent_selector, condition)

    cond do
      is_map(value) and conditional?(value) -> flatten(value, current_selector)
      is_list(value) and conditional?(value) -> flatten(value, current_selector)
      true -> [{current_selector, value}]
    end
  end

  @doc false
  @spec combine_selectors(String.t() | nil, atom() | String.t()) :: String.t() | nil
  def combine_selectors(nil, key) when key in [:default, "default"], do: nil
  def combine_selectors(parent, key) when key in [:default, "default"], do: parent

  def combine_selectors(nil, condition) when is_atom(condition) do
    to_string(condition)
  end

  def combine_selectors(nil, condition) when is_binary(condition), do: condition

  def combine_selectors(parent, condition) when is_atom(condition) do
    parent <> to_string(condition)
  end

  def combine_selectors(parent, condition) when is_binary(condition) do
    parent <> condition
  end

  @doc false
  @spec selector_key?(atom() | String.t()) :: boolean()
  def selector_key?(key) when is_atom(key), do: selector_key?(Atom.to_string(key))
  def selector_key?(<<":", _rest::binary>>), do: true
  def selector_key?(<<"@", _rest::binary>>), do: true
  def selector_key?(_), do: false
end
