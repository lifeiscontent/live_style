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

      iex> AcceptShorthands.expand("margin", "10px")
      [{:margin, "10px"}]

  ## Data-Driven Expansions

  Expansion mappings are loaded at compile time from `data/keep_shorthands_expansions.txt`.
  This data defines which properties are related to each shorthand and need nil resets
  for cascade control.
  """

  @behaviour LiveStyle.ShorthandBehavior

  alias LiveStyle.Data

  # Load data at compile time
  @shorthand_properties Data.shorthand_properties()
  @keep_shorthands_expansions Data.keep_shorthands_expansions()

  # ==========================================================================
  # Public API
  # ==========================================================================

  @doc """
  Expands a CSS property and value according to the AcceptShorthands behavior.

  Returns a list of `{property_atom, value}` tuples. For shorthand properties,
  returns the shorthand with its value (nil resets are filtered out).
  For non-shorthand properties, returns the property unchanged.

  ## Examples

      iex> AcceptShorthands.expand("margin", "10px")
      [{:margin, "10px"}]

      iex> AcceptShorthands.expand("color", "red")
      [{:color, "red"}]

  """
  def expand(css_property, value) when is_binary(css_property) do
    case get_expansion(css_property) do
      nil ->
        # Not a shorthand, pass through
        [{css_to_atom(css_property), value}]

      expansion ->
        # Apply expansion and filter out nils
        expansion
        |> apply_expansion(value)
        |> Enum.reject(fn {_prop, val} -> is_nil(val) end)
    end
  end

  # ==========================================================================
  # Behavior Callbacks
  # ==========================================================================

  @impl true
  def expand_declaration(key, value, _opts) do
    css_property = to_css_property(key)
    expand(css_property, value)
  end

  @impl true
  def expand_shorthand_conditions(key, css_property, conditions, _opts) do
    case get_expansion(css_property) do
      nil ->
        [{key, conditions}]

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

  # Build expansion map at compile time: css_property -> [{atom, :value | :nil}, ...]
  @expansions (for {func_name, props} <- @keep_shorthands_expansions, into: %{} do
                 # Convert function name back to CSS property
                 # e.g., :expand_margin_block -> "margin-block"
                 css_prop =
                   func_name
                   |> Atom.to_string()
                   |> String.replace_prefix("expand_", "")
                   |> String.replace("_", "-")

                 {css_prop, props}
               end)

  # Add complex expansions that require runtime parsing
  @complex_expansions %{
    "overscroll-behavior" => :overscroll_behavior,
    "contain-intrinsic-size" => :contain_intrinsic_size
  }

  # Generate lookup function for simple expansions
  for {css_prop, props} <- @expansions do
    defp get_expansion(unquote(css_prop)), do: {:simple, unquote(Macro.escape(props))}
  end

  # Add aliases from shorthand_properties
  for {property, expansion_fn} <- @shorthand_properties do
    # Skip if already defined above
    unless Map.has_key?(@expansions, property) do
      # Find the canonical property this aliases to
      canonical =
        expansion_fn
        |> Atom.to_string()
        |> String.replace_prefix("expand_", "")
        |> String.replace("_", "-")

      if Map.has_key?(@expansions, canonical) do
        defp get_expansion(unquote(property)), do: get_expansion(unquote(canonical))
      end
    end
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

    [{:overscroll_behavior_x, x}, {:overscroll_behavior_y, y}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, nil) do
    [{:contain_intrinsic_width, nil}, {:contain_intrinsic_height, nil}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, value) when is_binary(value) do
    {width, height} = parse_contain_intrinsic_values(value)
    [{:contain_intrinsic_width, width}, {:contain_intrinsic_height, height}]
  end

  defp apply_expansion({:complex, :contain_intrinsic_size}, value) do
    [{:contain_intrinsic_width, value}, {:contain_intrinsic_height, value}]
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

    parts = do_split_css_value(base_value, [], "", 0)
    if important?, do: Enum.map(parts, &(&1 <> " !important")), else: parts
  end

  defp split_css_value(value), do: [value]

  defp do_split_css_value("", acc, current, _depth) do
    case String.trim(current) do
      "" -> Enum.reverse(acc)
      trimmed -> Enum.reverse([trimmed | acc])
    end
  end

  defp do_split_css_value(<<" ", rest::binary>>, acc, current, 0) do
    case String.trim(current) do
      "" -> do_split_css_value(rest, acc, "", 0)
      trimmed -> do_split_css_value(rest, [trimmed | acc], "", 0)
    end
  end

  defp do_split_css_value(<<"(", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> "(", depth + 1)

  defp do_split_css_value(<<")", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> ")", max(0, depth - 1))

  defp do_split_css_value(<<char::utf8, rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> <<char::utf8>>, depth)

  # ==========================================================================
  # Utility Functions
  # ==========================================================================

  defp css_to_atom(css_property) do
    css_property
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp to_css_property(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp to_css_property(key) when is_binary(key), do: key
end
