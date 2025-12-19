defmodule LiveStyle.RTL do
  @moduledoc """
  RTL/LTR bidirectional support for LiveStyle.

  Following StyleX's physical-rtl approach:
  1. Logical properties are transformed to physical properties
  2. LTR: logical → physical left
  3. RTL: logical → physical right (wrapped in html[dir="rtl"] selector)

  Uses compile-time generated function clauses for optimized property lookups.
  """

  alias LiveStyle.Data

  # Load mappings at compile time
  @ltr_mappings Data.logical_to_ltr()
  @rtl_mappings Data.logical_to_rtl()
  @ltr_values Data.logical_value_to_ltr()
  @rtl_values Data.logical_value_to_rtl()

  # Generate function clauses for LTR property mapping
  for {logical, physical} <- @ltr_mappings do
    defp ltr_property(unquote(logical)), do: unquote(physical)
  end

  defp ltr_property(_), do: nil

  # Generate function clauses for RTL property mapping
  for {logical, physical} <- @rtl_mappings do
    defp rtl_property(unquote(logical)), do: unquote(physical)
  end

  defp rtl_property(_), do: nil

  # Generate function clauses for LTR value mapping
  for {logical, physical} <- @ltr_values do
    defp ltr_value(unquote(logical)), do: unquote(physical)
  end

  defp ltr_value(value), do: value

  # Generate function clauses for RTL value mapping
  for {logical, physical} <- @rtl_values do
    defp rtl_value(unquote(logical)), do: unquote(physical)
  end

  defp rtl_value(value), do: value

  # Check if value has RTL mapping
  for {logical, _physical} <- @rtl_values do
    defp has_rtl_value?(unquote(logical)), do: true
  end

  defp has_rtl_value?(_), do: false

  @doc """
  Generate LTR and RTL CSS rules for a property/value pair (simple version).

  Returns `{ltr_property, ltr_value, rtl_css_or_nil}` where:
  - ltr_property: The physical property name for LTR
  - ltr_value: The physical value for LTR
  - rtl_css_or_nil: The RTL CSS override rule string, or nil if not needed
  """
  def generate_ltr_rtl(css_property, css_value, class_name) do
    generate_ltr_rtl(css_property, css_value, class_name, nil, nil)
  end

  @doc """
  Generate LTR and RTL CSS rules for a property/value pair (full version).

  Returns `{ltr_property, ltr_value, rtl_rule_or_nil}` where:
  - ltr_property: The physical property name for LTR
  - ltr_value: The physical value for LTR
  - rtl_rule_or_nil: The RTL CSS override rule, or nil if not needed
  """
  def generate_ltr_rtl(css_property, css_value, class_name, selector_suffix, at_rule) do
    {ltr_prop, ltr_val} = generate_ltr(css_property, css_value)
    rtl_result = generate_rtl(css_property, css_value)

    rtl_rule =
      case rtl_result do
        nil ->
          nil

        {rtl_prop, rtl_val} ->
          build_rtl_rule(class_name, rtl_prop, rtl_val, selector_suffix, at_rule)
      end

    {ltr_prop, ltr_val, rtl_rule}
  end

  @doc """
  Generate LTR (left-to-right) physical property and value.
  Uses compile-time generated function clauses for O(1) lookups.
  """
  def generate_ltr(css_property, css_value) do
    # Check if property needs transformation using generated function
    case ltr_property(css_property) do
      nil ->
        # Check if value needs transformation (for float, clear, etc.)
        transformed_value = transform_value_ltr(css_property, css_value)
        {css_property, transformed_value}

      physical_property ->
        {physical_property, css_value}
    end
  end

  @doc """
  Generate RTL (right-to-left) physical property and value.
  Returns nil if no RTL override is needed.
  Uses compile-time generated function clauses for O(1) lookups.
  """
  def generate_rtl(css_property, css_value) do
    cond do
      # Property is a logical property that needs RTL override
      ltr_property(css_property) != nil ->
        {rtl_property(css_property), css_value}

      # Value contains logical keywords that need flipping
      needs_value_rtl?(css_property, css_value) ->
        {css_property, transform_value_rtl(css_property, css_value)}

      # Background-position with logical values
      css_property == "background-position" ->
        flip_background_position_rtl(css_value)

      # NOTE: StyleX has `enableLegacyValueFlipping` option (default: false) for
      # cursor and shadow flipping. This is marked as "Legacy / Incorrect" in StyleX.
      # LiveStyle follows StyleX's modern behavior and does NOT flip these by default.
      # If legacy behavior is needed, it can be added as a configuration option.

      true ->
        nil
    end
  end

  # Transform logical values to physical for LTR
  # NOTE: text-align is NOT included because browsers handle start/end natively
  defp transform_value_ltr(property, value) when property in ["float", "clear"] do
    ltr_value(value)
  end

  defp transform_value_ltr("background-position", value) do
    flip_background_position_ltr(value)
  end

  defp transform_value_ltr(_property, value), do: value

  # Transform background-position logical values to physical for LTR
  defp flip_background_position_ltr(value) do
    value
    |> String.split(" ")
    |> Enum.map_join(" ", fn
      "start" -> "left"
      "inline-start" -> "left"
      "end" -> "right"
      "inline-end" -> "right"
      other -> other
    end)
  end

  # Check if value needs RTL transformation
  # NOTE: text-align is NOT included because browsers handle start/end natively
  defp needs_value_rtl?(property, value) when property in ["float", "clear"] do
    has_rtl_value?(value)
  end

  defp needs_value_rtl?(_property, _value), do: false

  # Transform logical values to physical for RTL
  # NOTE: text-align is NOT included because browsers handle start/end natively
  defp transform_value_rtl(property, value) when property in ["float", "clear"] do
    rtl_value(value)
  end

  defp transform_value_rtl(_property, value), do: value

  # Flip background-position logical values
  defp flip_background_position_rtl(value) do
    words = String.split(value, " ")

    if Enum.any?(words, &(&1 in ["start", "end", "inline-start", "inline-end"])) do
      flipped =
        Enum.map_join(words, " ", fn
          "start" -> "right"
          "inline-start" -> "right"
          "end" -> "left"
          "inline-end" -> "left"
          other -> other
        end)

      {"background-position", flipped}
    else
      nil
    end
  end

  # Build RTL CSS rule with html[dir="rtl"] selector
  defp build_rtl_rule(class_name, property, value, nil, nil) do
    "html[dir=\"rtl\"] .#{class_name} { #{property}: #{value}; }"
  end

  defp build_rtl_rule(class_name, property, value, selector_suffix, nil) do
    "html[dir=\"rtl\"] .#{class_name}#{selector_suffix} { #{property}: #{value}; }"
  end

  defp build_rtl_rule(class_name, property, value, nil, at_rule) do
    "#{at_rule} { html[dir=\"rtl\"] .#{class_name} { #{property}: #{value}; } }"
  end

  defp build_rtl_rule(class_name, property, value, selector_suffix, at_rule) do
    "#{at_rule} { html[dir=\"rtl\"] .#{class_name}#{selector_suffix} { #{property}: #{value}; } }"
  end
end
