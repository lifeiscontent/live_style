defmodule LiveStyle.ShorthandBehavior.FlattenShorthands do
  @moduledoc """
  Expands shorthand properties to their constituent longhands.

  This behavior fully expands shorthand properties to their individual
  longhand properties. For example, `margin: "10px 20px"` becomes
  four separate margin properties.

  More verbose CSS output but predictable specificity.

  ## How It Works

  When you use a shorthand like `margin: "10px 20px"`, this behavior:
  1. Parses the multi-value input (CSS box model: top right bottom left)
  2. Returns individual longhand properties with their computed values

  ## Example

      iex> FlattenShorthands.expand_declaration("margin", "10px 20px", %{})
      [
        {"margin-top", "10px"},
        {"margin-right", "20px"},
        {"margin-bottom", "10px"},
        {"margin-left", "20px"}
      ]

  ## Data-Driven Expansions

  Expansion patterns are loaded at compile time from `data/expand_to_longhands_expansions.txt`.
  This data defines the multi-value parsing pattern and target longhands for each
  supported shorthand property.

  Supported patterns:
  - `4-value` - CSS box model (margin, padding, border-width, etc.)
  - `2-value` - Two values (gap, overflow, margin-block, etc.)
  - `border-radius` - Special handling for slash syntax
  - `list-style` - Special parsing for type/position/image
  """

  @behaviour LiveStyle.ShorthandBehavior

  alias LiveStyle.PropertyMetadata

  # Load data at compile time
  @shorthand_properties PropertyMetadata.shorthand_properties()
  @expand_to_longhands_expansions PropertyMetadata.expand_to_longhands_expansions()

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
        # Apply expansion with value parsing
        apply_expansion(expansion, css_property, value)
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

  # ==========================================================================
  # Expansion Data
  # ==========================================================================

  # Generate lookup for expansions with patterns
  for {css_prop, {pattern, longhands}} <- @expand_to_longhands_expansions do
    defp get_expansion(unquote(css_prop)), do: {unquote(pattern), unquote(longhands)}
  end

  # Check shorthand_properties for properties that should be expanded but don't have
  # a specific pattern (pass through as single longhand)
  for {property, _expansion_fn} <- @shorthand_properties do
    unless Map.has_key?(@expand_to_longhands_expansions, property) do
      defp get_expansion(unquote(property)), do: :passthrough
    end
  end

  # Default: not a shorthand
  defp get_expansion(_), do: nil

  # ==========================================================================
  # Expansion Application
  # ==========================================================================

  defp apply_expansion(:passthrough, css_property, value) do
    [{css_property, value}]
  end

  defp apply_expansion({:"4-value", longhands}, _css_property, value) when is_binary(value) do
    {clean_value, important} = extract_important(value)
    expand_4_value(clean_value, longhands, important)
  end

  defp apply_expansion({:"2-value", longhands}, _css_property, value) when is_binary(value) do
    {clean_value, important} = extract_important(value)
    expand_2_value(clean_value, longhands, important)
  end

  defp apply_expansion({:"border-radius", longhands}, _css_property, value)
       when is_binary(value) do
    {clean_value, important} = extract_important(value)
    expand_border_radius(clean_value, longhands, important)
  end

  defp apply_expansion({:"list-style", _longhands}, _css_property, value) when is_binary(value) do
    {clean_value, important} = extract_important(value)
    expand_list_style(clean_value, important)
  end

  defp apply_expansion({_pattern, _longhands}, css_property, value) do
    # Non-string values pass through
    [{css_property, value}]
  end

  # ==========================================================================
  # Value Parsing Helpers
  # ==========================================================================

  defp extract_important(value) do
    if String.ends_with?(value, "!important") do
      {String.trim(String.replace(value, "!important", "")), " !important"}
    else
      {value, ""}
    end
  end

  defp split_value(value), do: LiveStyle.Utils.split_css_value(value)

  # ==========================================================================
  # Pattern-Specific Expansion
  # ==========================================================================

  defp expand_4_value(value, [top, right, bottom, left], important) do
    parts = split_value(value)

    {t, r, b, l} =
      case parts do
        [v] -> {v, v, v, v}
        [v, h] -> {v, h, v, h}
        [t, h, b] -> {t, h, b, h}
        [t, r, b, l] -> {t, r, b, l}
        _ -> {value, value, value, value}
      end

    [
      {top, t <> important},
      {right, r <> important},
      {bottom, b <> important},
      {left, l <> important}
    ]
  end

  defp expand_2_value(value, [first, second], important) do
    parts = split_value(value)

    {v1, v2} =
      case parts do
        [v] -> {v, v}
        [v1, v2] -> {v1, v2}
        _ -> {value, value}
      end

    [{first, v1 <> important}, {second, v2 <> important}]
  end

  defp expand_border_radius(value, longhands, important) do
    if String.contains?(value, "/") do
      expand_border_radius_with_slash(value, longhands, important)
    else
      expand_4_value(value, longhands, important)
    end
  end

  defp expand_border_radius_with_slash(value, props, important) do
    [h_part, v_part] = String.split(value, "/", parts: 2) |> Enum.map(&String.trim/1)
    h_values = split_value(h_part)
    v_values = split_value(v_part)
    h4 = expand_to_4(h_values)
    v4 = expand_to_4(v_values)

    Enum.zip(props, Enum.zip(h4, v4))
    |> Enum.map(fn {prop, {h, v}} ->
      combined = if h == v, do: h, else: "#{h} #{v}"
      {prop, combined <> important}
    end)
  end

  defp expand_to_4([v]), do: [v, v, v, v]
  defp expand_to_4([v, h]), do: [v, h, v, h]
  defp expand_to_4([t, h, b]), do: [t, h, b, h]
  defp expand_to_4([t, r, b, l]), do: [t, r, b, l]
  defp expand_to_4(v), do: [v, v, v, v]

  defp expand_list_style(value, important) do
    parts = split_value(value)

    {type, position, image} =
      Enum.reduce(parts, {nil, nil, nil}, fn part, {t, p, i} ->
        case part do
          <<"url(", _::binary>> -> {t, p, part}
          "none" when i == nil -> {t, p, part}
          "inside" -> {t, part, i}
          "outside" -> {t, part, i}
          _ -> {part, p, i}
        end
      end)

    result = []
    result = if type, do: [{"list-style-type", type <> important} | result], else: result

    result =
      if position, do: [{"list-style-position", position <> important} | result], else: result

    result = if image, do: [{"list-style-image", image <> important} | result], else: result
    Enum.reverse(result)
  end

  # ==========================================================================
  # Conditional Expansion Helpers
  # ==========================================================================

  defp do_expand_conditions(expansion, css_property, conditions) do
    conditions
    |> Enum.flat_map(&expand_condition_to_props(expansion, css_property, &1))
    |> Enum.group_by(fn {prop, _} -> prop end, fn {_, cond_map} -> cond_map end)
    |> Enum.map(&merge_condition_maps/1)
  end

  defp expand_condition_to_props(expansion, css_property, {condition, value}) do
    expanded = apply_expansion(expansion, css_property, value)
    Enum.map(expanded, fn {prop, val} -> {prop, %{condition => val}} end)
  end

  defp merge_condition_maps({prop, cond_maps}) do
    merged = Enum.reduce(cond_maps, %{}, &Map.merge(&2, &1))
    {prop, merged}
  end
end
