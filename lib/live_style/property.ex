defmodule LiveStyle.Property do
  @moduledoc """
  CSS property information and lookups.

  This module provides compile-time generated function clauses for efficient
  property lookups, following the pattern used by the unicode library.

  All property data is loaded from external files at compile time via
  `LiveStyle.PropertyMetadata`, enabling:
  - O(1) pattern-matched lookups instead of runtime lookups
  - Automatic recompilation when data files change
  - Single source of truth for property metadata

  ## Property Categories

  CSS properties are categorized by their specificity level:
  - `:shorthands_of_shorthands` - Affect many properties (e.g., `margin`, `padding`)
  - `:shorthands_of_longhands` - Expand to fewer properties (e.g., `margin-block`)
  - `:longhand_logical` - Logical longhand properties (default)
  - `:longhand_physical` - Physical longhand properties (e.g., `margin-top`)

  ## Examples

      iex> LiveStyle.Property.category("margin")
      :shorthands_of_shorthands

      iex> LiveStyle.Property.category("color")
      :longhand_logical

      iex> LiveStyle.Property.unitless?("opacity")
      true

      iex> LiveStyle.Property.time?("animation-duration")
      true
  """

  alias LiveStyle.PropertyMetadata

  @property_priorities PropertyMetadata.property_priorities()
  @unitless_properties PropertyMetadata.unitless_properties()
  @time_properties PropertyMetadata.time_properties()
  @position_try_properties PropertyMetadata.position_try_properties()
  @rtl_value_properties PropertyMetadata.rtl_value_properties()
  @disallowed_shorthands PropertyMetadata.disallowed_shorthands()

  @doc """
  Returns the category of a CSS property.

  Categories determine property priority in the generated CSS.

  ## Categories

  - `:shorthands_of_shorthands` - Priority 1000 (e.g., `margin`, `padding`)
  - `:shorthands_of_longhands` - Priority 2000 (e.g., `margin-block`, `border-color`)
  - `:longhand_logical` - Priority 3000 (default for unlisted properties)
  - `:longhand_physical` - Priority 4000 (e.g., `margin-top`, `width`)

  ## Examples

      iex> LiveStyle.Property.category("margin")
      :shorthands_of_shorthands

      iex> LiveStyle.Property.category("border-color")
      :shorthands_of_longhands

      iex> LiveStyle.Property.category("color")
      :longhand_logical

      iex> LiveStyle.Property.category("width")
      :longhand_physical
  """
  @spec category(String.t()) :: atom()

  # Custom properties have their own category
  def category(<<"--", _rest::binary>>), do: :custom_property

  # Generate function clauses for each property in the data file
  for {property, cat} <- @property_priorities do
    def category(unquote(property)), do: unquote(cat)
  end

  # Default to longhand_logical for unlisted properties
  def category(_), do: :longhand_logical

  @doc """
  Returns true if the property should not have a unit appended to numeric values.

  Properties like `opacity`, `z-index`, `flex-grow` etc. are unitless.

  ## Examples

      iex> LiveStyle.Property.unitless?("opacity")
      true

      iex> LiveStyle.Property.unitless?("z-index")
      true

      iex> LiveStyle.Property.unitless?("width")
      false
  """
  @spec unitless?(String.t()) :: boolean()

  # Custom properties are unitless
  def unitless?(<<"--", _rest::binary>>), do: true

  # Generate function clauses for each unitless property
  for property <- @unitless_properties do
    def unitless?(unquote(property)), do: true
  end

  def unitless?(_), do: false

  @doc """
  Returns true if the property uses time units (ms/s) for numeric values.

  ## Examples

      iex> LiveStyle.Property.time?("animation-duration")
      true

      iex> LiveStyle.Property.time?("transition-delay")
      true

      iex> LiveStyle.Property.time?("width")
      false
  """
  @spec time?(String.t()) :: boolean()

  # Generate function clauses for each time property
  for property <- @time_properties do
    def time?(unquote(property)), do: true
  end

  def time?(_), do: false

  @doc """
  Returns true if the property is allowed in @position-try rules.

  ## Examples

      iex> LiveStyle.Property.position_try?("top")
      true

      iex> LiveStyle.Property.position_try?("width")
      true

      iex> LiveStyle.Property.position_try?("color")
      false
  """
  @spec position_try?(String.t()) :: boolean()

  # Generate function clauses for each position-try property
  for property <- @position_try_properties do
    def position_try?(unquote(property)), do: true
  end

  def position_try?(_), do: false

  @doc """
  Returns true if the property needs value flipping in RTL mode.

  Properties like `text-align`, `float`, etc. have values that need
  to be flipped (e.g., `left` -> `right`) in RTL layouts.

  ## Examples

      iex> LiveStyle.Property.rtl_value?("text-align")
      true

      iex> LiveStyle.Property.rtl_value?("float")
      true

      iex> LiveStyle.Property.rtl_value?("color")
      false
  """
  @spec rtl_value?(String.t()) :: boolean()

  # Generate function clauses for each RTL value property
  for property <- @rtl_value_properties do
    def rtl_value?(unquote(property)), do: true
  end

  def rtl_value?(_), do: false

  @doc """
  Returns true if the property is a disallowed shorthand in strict mode.

  ## Examples

      iex> LiveStyle.Property.disallowed_shorthand?("background")
      true

      iex> LiveStyle.Property.disallowed_shorthand?("margin")
      false
  """
  @spec disallowed_shorthand?(String.t()) :: boolean()

  # Generate function clauses for each disallowed shorthand
  for property <- @disallowed_shorthands do
    def disallowed_shorthand?(unquote(property)), do: true
  end

  def disallowed_shorthand?(_), do: false

  @doc """
  Returns the appropriate unit suffix for a numeric value of this property.

  ## Examples

      iex> LiveStyle.Property.unit_suffix("width")
      "px"

      iex> LiveStyle.Property.unit_suffix("opacity")
      ""

      iex> LiveStyle.Property.unit_suffix("animation-duration")
      "ms"
  """
  @spec unit_suffix(String.t() | nil) :: String.t()
  def unit_suffix(nil), do: ""

  def unit_suffix(property), do: determine_unit(unitless?(property), time?(property))

  defp determine_unit(true, _time?), do: ""
  defp determine_unit(false, true), do: "ms"
  defp determine_unit(false, false), do: "px"

  @doc "Returns all position-try properties as a MapSet."
  def position_try_properties, do: @position_try_properties
end
