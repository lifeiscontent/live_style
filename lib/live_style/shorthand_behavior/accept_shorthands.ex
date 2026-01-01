defmodule LiveStyle.ShorthandBehavior.AcceptShorthands do
  @moduledoc """
  Keeps shorthand properties intact with nil resets for longhands.

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

  alias LiveStyle.PropertyMetadata

  # Load data at compile time
  @keep_shorthands_expansions PropertyMetadata.keep_shorthands_expansions()

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
        do_expand_conditions(expansion, css_property, conditions)
    end
  end

  defp do_expand_conditions(expansion, css_property, conditions) do
    conditions
    |> Enum.flat_map(&expand_condition_to_props(expansion, css_property, &1))
    |> Enum.group_by(fn {prop, _} -> prop end, fn {_, cond_entry} -> cond_entry end)
    |> Enum.map(&merge_condition_entries/1)
    |> Enum.reject(fn {_prop, conds} -> conds == [] end)
  end

  defp expand_condition_to_props(expansion, _css_property, {condition, value}) do
    expanded = apply_expansion(expansion, value)
    Enum.map(expanded, fn {prop, val} -> {prop, {condition, val}} end)
  end

  # Merge condition entries and return as sorted list for deterministic iteration
  defp merge_condition_entries({prop, cond_entries}) do
    merged =
      cond_entries
      |> Enum.reduce([], &merge_entry/2)
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)

    {prop, merged}
  end

  # Skip nil values
  defp merge_entry({_condition, nil}, acc), do: acc

  # Replace existing or prepend
  defp merge_entry({condition, val}, acc) do
    case List.keyfind(acc, condition, 0) do
      nil -> [{condition, val} | acc]
      _ -> List.keyreplace(acc, condition, 0, {condition, val})
    end
  end

  # ==========================================================================
  # Expansion Data
  # ==========================================================================

  # Expansion map from keep_shorthands_expansions.txt
  # Format: css_property -> [{css_property_string, :value | :nil}, ...]
  @expansions @keep_shorthands_expansions

  # Add complex expansions that require runtime parsing
  @complex_expansions [
    {"overscroll-behavior", :overscroll_behavior},
    {"contain-intrinsic-size", :contain_intrinsic_size}
  ]

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
