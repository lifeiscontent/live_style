defmodule LiveStyle.Class.Conditional do
  @moduledoc """
  Conditional value detection and flattening for LiveStyle class processing.

  This module handles CSS values that vary based on selectors (pseudo-classes,
  media queries, etc.). It provides:

  - Detection of conditional values (maps/lists with selector keys)
  - Flattening nested conditional structures
  - Selector combination (parent + child selectors)

  ## Conditional Value Format

  Conditional values are maps or keyword lists where keys are CSS selectors:

      %{
        default: "black",
        ":hover": "red",
        "@media (min-width: 800px)": %{
          default: "blue",
          ":hover": "green"
        }
      }

  These get flattened into a list of `{selector, value}` tuples for processing.

  ## Examples

      iex> conditional?(%{default: "red", ":hover": "blue"})
      true

      iex> conditional?("static-value")
      false

      iex> flatten(%{default: "black", ":hover": "red"}, nil)
      [{nil, "black"}, {":hover", "red"}]
  """

  @doc """
  Check if a value is a conditional value (varies by selector).

  A value is conditional if it's a map or list where:
  - It has a `:default` or `"default"` key, OR
  - All keys are selector-like (start with `:` or `@`)

  But NOT if it contains CSS property keys (like pseudo-element declarations).

  ## Examples

      iex> LiveStyle.Class.Conditional.conditional?(%{default: "red", ":hover": "blue"})
      true

      iex> LiveStyle.Class.Conditional.conditional?(%{content: "''", display: "block"})
      false

      iex> LiveStyle.Class.Conditional.conditional?("static")
      false
  """
  @spec conditional?(term()) :: boolean()
  def conditional?(value) when is_map(value) do
    has_default = Map.has_key?(value, :default) or Map.has_key?(value, "default")
    has_css_props = Enum.any?(Map.keys(value), &css_property_key?/1)
    all_selector_keys = Enum.all?(Map.keys(value), &selector_key?/1)

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

  # Support tuple syntax: {":hover", "value"} as shorthand for %{":hover" => "value"}
  def conditional?({key, _value}) when is_binary(key), do: selector_key?(key)
  def conditional?({key, _value}) when is_atom(key), do: selector_key?(key)
  def conditional?(_), do: false

  @doc """
  Recursively flatten nested conditional values into `{selector, value}` tuples.

  Handles arbitrarily nested conditional maps/lists, combining selectors as it descends.

  ## Examples

      iex> flatten(%{default: "black", ":hover": "red"}, nil)
      [{nil, "black"}, {":hover", "red"}]

      iex> flatten(%{":hover": %{default: "red", ":focus": "blue"}}, nil)
      [{":hover", "red"}, {":hover:focus", "blue"}]

      iex> flatten(%{"@media (x)": %{default: "a", ":hover": "b"}}, nil)
      [{"@media (x)", "a"}, {"@media (x):hover", "b"}]
  """
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

  # Handle lists (keyword lists or tuple lists) by converting to map
  def flatten(value_list, parent_selector) when is_list(value_list) do
    if conditional?(value_list) do
      # Convert tuple list to map and recurse
      flatten(Map.new(value_list), parent_selector)
    else
      [{parent_selector, value_list}]
    end
  end

  # Handle tuple syntax: {":hover", "value"} as shorthand for single condition
  def flatten({selector, value}, parent_selector)
      when is_binary(selector) or is_atom(selector) do
    selector_str = to_string(selector)

    if selector_key?(selector_str) do
      current_selector = combine_selectors(parent_selector, selector_str)

      # Check if the value itself is a nested conditional
      if conditional?(value) do
        # Recurse for nested conditionals like {":hover", {":active", "red"}}
        flatten(value, current_selector)
      else
        [{current_selector, value}]
      end
    else
      [{parent_selector, {selector, value}}]
    end
  end

  def flatten(value, parent_selector) do
    [{parent_selector, value}]
  end

  @doc """
  Combine parent and child selectors into a single selector string.

  Handles the special `:default` / `"default"` key which represents the
  unconditional value.

  ## Examples

      iex> combine_selectors(nil, :default)
      nil

      iex> combine_selectors(nil, ":hover")
      ":hover"

      iex> combine_selectors(":hover", ":focus")
      ":hover:focus"

      iex> combine_selectors("@media (x)", ":hover")
      "@media (x):hover"
  """
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

  @doc """
  Check if a key looks like a CSS selector (pseudo-class, pseudo-element, at-rule).

  ## Examples

      iex> selector_key?(":hover")
      true

      iex> selector_key?("@media (min-width: 800px)")
      true

      iex> selector_key?(:display)
      false
  """
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
