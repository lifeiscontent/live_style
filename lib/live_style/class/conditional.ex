defmodule LiveStyle.Class.Conditional do
  @moduledoc false
  # Internal module for conditional value detection and flattening.

  @doc false
  @spec conditional?(term()) :: boolean()
  def conditional?(value) when is_map(value) do
    keys = Map.keys(value)
    has_default = :default in keys or "default" in keys
    has_css_props = Enum.any?(keys, &css_property_key?/1)
    all_selector_keys = Enum.all?(keys, &selector_key?/1)

    (has_default or all_selector_keys) and not has_css_props
  end

  def conditional?(value) when is_list(value) do
    has_default =
      Enum.any?(value, fn
        {:default, _} -> true
        {"default", _} -> true
        _ -> false
      end)

    all_selector_keys =
      Enum.all?(value, fn
        {key, _} -> selector_key?(key)
        _ -> false
      end)

    has_default or all_selector_keys
  end

  def conditional?(_), do: false

  @doc false
  @spec flatten(term(), String.t() | nil) :: [{String.t() | nil, term()}]
  def flatten(value_map, parent_selector) when is_map(value_map) do
    Enum.flat_map(value_map, fn {condition, value} ->
      current_selector = combine_selectors(parent_selector, condition)

      cond do
        is_map(value) and conditional?(value) ->
          # Nested conditional map - recurse
          flatten(value, current_selector)

        is_list(value) and conditional?(value) ->
          # Nested conditional keyword list - convert to map and recurse
          flatten(Map.new(value), current_selector)

        true ->
          # Leaf value
          [{current_selector, value}]
      end
    end)
  end

  # Handle lists (keyword lists) by converting to map
  def flatten(value_list, parent_selector) when is_list(value_list) do
    if conditional?(value_list) do
      # Convert tuple list to map and recurse
      flatten(Map.new(value_list), parent_selector)
    else
      [{parent_selector, value_list}]
    end
  end

  def flatten(value, parent_selector) do
    [{parent_selector, value}]
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
  def selector_key?(key) when is_atom(key) do
    selector_key?(Atom.to_string(key))
  end

  def selector_key?(<<":", _rest::binary>>), do: true
  def selector_key?(<<"@", _rest::binary>>), do: true
  def selector_key?(_), do: false

  # Check if a key looks like a CSS property (for distinguishing from selectors)
  defp css_property_key?(key) when is_atom(key) do
    key_str = Atom.to_string(key)
    # CSS properties use snake_case or have common property names
    String.contains?(key_str, "_") or
      key in [:content, :display, :color, :opacity, :position, :width, :height]
  end

  defp css_property_key?(_), do: false
end
