defmodule LiveStyle.RTL do
  @moduledoc false
  # Internal module for RTL/LTR bidirectional CSS support.

  alias LiveStyle.PropertyMetadata

  # Load mappings at compile time
  @ltr_mappings PropertyMetadata.logical_to_ltr()
  @rtl_mappings PropertyMetadata.logical_to_rtl()
  @ltr_values PropertyMetadata.logical_value_to_ltr()
  @rtl_values PropertyMetadata.logical_value_to_rtl()

  # Properties with logical values that need physical transformation
  # NOTE: text-align is NOT included because browsers handle start/end natively
  @logical_value_properties ["float", "clear"]

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

  @doc false
  @spec generate_ltr(String.t(), String.t()) :: {String.t(), String.t()}
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

  @doc false
  @spec generate_rtl(String.t(), String.t()) :: {String.t(), String.t()} | nil
  def generate_rtl(css_property, css_value) do
    # NOTE: StyleX has `enableLegacyValueFlipping` option (default: false) for
    # cursor and shadow flipping. This is marked as "Legacy / Incorrect" in StyleX.
    # LiveStyle follows StyleX's modern behavior and does NOT flip these by default.
    # If legacy behavior is needed, it can be added as a configuration option.
    generate_rtl_for_property(css_property, css_value) ||
      generate_rtl_for_value(css_property, css_value)
  end

  # Property is a logical property that needs RTL override
  defp generate_rtl_for_property(css_property, css_value) do
    case ltr_property(css_property) do
      nil -> nil
      _ -> {rtl_property(css_property), css_value}
    end
  end

  # Background-position with logical values
  defp generate_rtl_for_value("background-position", css_value) do
    flip_background_position_rtl(css_value)
  end

  # Value contains logical keywords that need flipping (for float, clear)
  defp generate_rtl_for_value(css_property, css_value) do
    if needs_value_rtl?(css_property, css_value) do
      {css_property, transform_value_rtl(css_property, css_value)}
    end
  end

  # Transform logical values to physical for LTR
  defp transform_value_ltr(property, value) when property in @logical_value_properties do
    ltr_value(value)
  end

  defp transform_value_ltr("background-position", value) do
    flip_background_position_ltr(value)
  end

  defp transform_value_ltr(_property, value), do: value

  # Shared helper for flipping background-position logical values
  @logical_position_values ["start", "end", "inline-start", "inline-end"]

  defp flip_background_position(value, mapping) do
    value
    |> String.split(" ")
    |> Enum.map_join(" ", fn word -> Map.get(mapping, word, word) end)
  end

  # Transform background-position logical values to physical for LTR
  @ltr_position_mapping %{
    "start" => "left",
    "inline-start" => "left",
    "end" => "right",
    "inline-end" => "right"
  }

  defp flip_background_position_ltr(value) do
    flip_background_position(value, @ltr_position_mapping)
  end

  # Check if value needs RTL transformation
  defp needs_value_rtl?(property, value) when property in @logical_value_properties do
    has_rtl_value?(value)
  end

  defp needs_value_rtl?(_property, _value), do: false

  # Transform logical values to physical for RTL
  defp transform_value_rtl(property, value) when property in @logical_value_properties do
    rtl_value(value)
  end

  defp transform_value_rtl(_property, value), do: value

  # Flip background-position logical values for RTL
  @rtl_position_mapping %{
    "start" => "right",
    "inline-start" => "right",
    "end" => "left",
    "inline-end" => "left"
  }

  defp flip_background_position_rtl(value) do
    words = String.split(value, " ")

    if Enum.any?(words, &(&1 in @logical_position_values)) do
      flipped = flip_background_position(value, @rtl_position_mapping)
      {"background-position", flipped}
    else
      nil
    end
  end
end
