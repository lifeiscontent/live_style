defmodule LiveStyle.ShorthandBehavior.AcceptShorthands do
  @moduledoc """
  Keeps shorthand properties intact with null resets for longhands.

  This is the default behavior. Shorthand properties are preserved,
  but conflicting longhand properties are reset to `nil` to ensure
  deterministic cascade behavior.

  ## How It Works

  When you use a shorthand like `margin: "10px"`, this behavior:
  1. Keeps the shorthand as the main value
  2. Returns the shorthand without nil resets (nils are filtered out)

  This ensures that later longhands properly override earlier shorthands
  through CSS cascade, while keeping the output minimal.

  ## Example

      iex> AcceptShorthands.expand_declaration("margin", "10px", %{})
      [{"margin", "10px"}]

  ## Data-Driven Expansions

  Expansion mappings are loaded at compile time from `data/keep_shorthands_expansions.txt`.
  This data defines which properties are related to each shorthand and need nil resets
  for cascade control.
  """

  @behaviour LiveStyle.ShorthandBehavior

  alias LiveStyle.Data

  # Load data at compile time
  @keep_shorthands_expansions Data.keep_shorthands_expansions()

  # ==========================================================================
  # Behavior Callbacks
  # ==========================================================================

  @impl true
  def expand_declaration(css_property, value, _opts) do
    case get_expansion(css_property) do
      nil ->
        # Not a shorthand, pass through
        [{css_property, value}]

      expansion ->
        # Apply expansion and filter out nils
        expansion
        |> apply_expansion(value)
        |> Enum.reject(fn {_prop, val} -> is_nil(val) end)
    end
  end

  @impl true
  def expand_shorthand_conditions(css_property, conditions, _opts) do
    case get_expansion(css_property) do
      nil ->
        [{css_property, conditions}]

      expansion ->
        expanded_props = get_expanded_property_names(expansion)
        expanded_conditions = expand_conditions_map(conditions, expansion)

        expanded_props
        |> Enum.map(&{&1, Map.get(expanded_conditions, &1)})
        |> Enum.reject(fn {_prop, val} -> is_nil(val) or val == %{} end)
    end
  end

  # ==========================================================================
  # Expansion Data
  # ==========================================================================

  # Expansion map from keep_shorthands_expansions.txt
  # Format: css_property -> [{css_property_string, :value | :nil}, ...]
  @expansions @keep_shorthands_expansions

  # Add complex expansions that require runtime parsing
  @complex_expansions %{
    "overscroll-behavior" => :overscroll_behavior,
    "contain-intrinsic-size" => :contain_intrinsic_size
  }

  # Generate lookup function for simple expansions
  for {css_prop, props} <- @expansions do
    defp get_expansion(unquote(css_prop)), do: {:simple, unquote(Macro.escape(props))}
  end

  # Complex expansions
  for {css_prop, type} <- @complex_expansions do
    defp get_expansion(unquote(css_prop)), do: {:complex, unquote(type)}
  end

  # Default: not a shorthand
  defp get_expansion(_), do: nil

  # ==========================================================================
  # Expansion Application
  # ==========================================================================

  defp apply_expansion({:simple, props}, value) do
    for {prop, type} <- props do
      case type do
        :value -> {prop, value}
        nil -> {prop, nil}
      end
    end
  end

  defp apply_expansion({:complex, :overscroll_behavior}, value) do
    parts = split_css_value(value)

    [x, y] =
      case parts do
        [single] -> [single, single]
        [a, b] -> [a, b]
        _ -> [nil, nil]
      end

    [{"overscroll-behavior-x", x}, {"overscroll-behavior-y", y}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, nil) do
    [{"contain-intrinsic-width", nil}, {"contain-intrinsic-height", nil}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, value) when is_binary(value) do
    {width, height} = parse_contain_intrinsic_values(value)
    [{"contain-intrinsic-width", width}, {"contain-intrinsic-height", height}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, value) do
    [{"contain-intrinsic-width", value}, {"contain-intrinsic-height", value}]
  end

  defp parse_contain_intrinsic_values(value) do
    parts = split_css_value(value)

    case parts do
      [single] -> {single, single}
      [w, h] -> {w, h}
      ["auto", size1, size2] -> {"auto #{size1}", size2}
      ["auto", size1, "auto", size2] -> {"auto #{size1}", "auto #{size2}"}
      [size1, "auto", size2] -> {size1, "auto #{size2}"}
      _ -> {value, value}
    end
  end

  # ==========================================================================
  # Conditional Expansion Helpers
  # ==========================================================================

  defp get_expanded_property_names(expansion) do
    apply_expansion(expansion, "sample")
    |> Enum.map(fn {prop, _} -> prop end)
  end

  defp expand_conditions_map(conditions, expansion) do
    Enum.reduce(conditions, %{}, fn {condition, value}, acc ->
      expanded = apply_expansion(expansion, value)
      merge_expanded_condition(expanded, condition, acc)
    end)
  end

  defp merge_expanded_condition(expanded, condition, acc) do
    Enum.reduce(expanded, acc, fn {prop, val}, inner_acc ->
      add_prop_condition(inner_acc, prop, condition, val)
    end)
  end

  defp add_prop_condition(acc, _prop, _condition, nil), do: acc

  defp add_prop_condition(acc, prop, condition, val) do
    prop_conditions = Map.get(acc, prop, %{})
    Map.put(acc, prop, Map.put(prop_conditions, condition, val))
  end

  # ==========================================================================
  # CSS Value Parsing Helpers
  # ==========================================================================

  defp split_css_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    {base_value, important?} =
      if String.ends_with?(String.downcase(trimmed), "!important") do
        {String.slice(trimmed, 0, String.length(trimmed) - 10) |> String.trim(), true}
      else
        {trimmed, false}
      end

    parts = LiveStyle.Utils.split_css_value(base_value)
    if important?, do: Enum.map(parts, &(&1 <> " !important")), else: parts
  end

  defp split_css_value(value), do: [value]
end
