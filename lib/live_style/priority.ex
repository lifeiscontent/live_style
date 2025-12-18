defmodule LiveStyle.Priority do
  @moduledoc """
  Priority calculation for CSS rules.

  This module implements the same priority system as StyleX to ensure
  CSS rules are ordered correctly in the generated stylesheet.

  Uses compile-time function generation from data files (like the unicode library)
  for optimized pattern matching lookups.

  ## Priority Tiers

  - Custom properties (`--*`): 1
  - Variables: 0.1
  - Keyframes: 0
  - Position-try: 0
  - Shorthands of shorthands (e.g., `margin`, `padding`): 1000
  - Shorthands of longhands (e.g., `margin-block`, `border-color`): 2000
  - Longhand logical (e.g., `color`, `display`): 3000
  - Longhand physical (e.g., `margin-top`, `margin-left`): 4000
  - Pseudo-elements (`::before`, etc.): 5000

  ## At-Rule Additions

  - `@supports`: +30
  - `@media`: +200
  - `@container`: +300

  ## Pseudo-Class Additions

  - `:hover`: +130
  - `:focus`: +150
  - `:active`: +170
  - etc.

  The final priority is: `property_priority + pseudo_priority + at_rule_priority`
  """

  alias LiveStyle.Property
  alias LiveStyle.Pseudo

  # At-rule priorities (small fixed set, keep inline)
  @at_rule_priorities %{
    "@supports" => 30,
    "@media" => 200,
    "@container" => 300
  }

  # ===========================================================================
  # Main Priority Calculation
  # ===========================================================================

  @doc """
  Calculate the priority for a CSS rule.

  Takes the property name, optional pseudo-class/element suffix, and optional at-rule.
  Returns an integer priority that matches StyleX's priority system.

  ## Examples

      iex> LiveStyle.Priority.calculate("color", nil, nil)
      3000

      iex> LiveStyle.Priority.calculate("color", ":hover", nil)
      3130

      iex> LiveStyle.Priority.calculate("color", nil, "@media (min-width: 800px)")
      3200

      iex> LiveStyle.Priority.calculate("color", ":hover", "@media (min-width: 800px)")
      3330
  """
  @spec calculate(String.t(), String.t() | nil, String.t() | nil) :: integer()
  def calculate(property, selector_suffix, at_rule) do
    property_priority = get_property_priority(property)
    pseudo_priority = get_pseudo_priority(selector_suffix)
    at_rule_priority = get_at_rule_priority(at_rule)

    property_priority + pseudo_priority + at_rule_priority
  end

  # ===========================================================================
  # Property Priority
  # ===========================================================================

  @doc """
  Get the base priority for a CSS property.

  Delegates to `LiveStyle.Property.category/1` for compile-time generated lookups.
  """
  @spec get_property_priority(String.t()) :: integer()
  def get_property_priority(property) do
    category_to_priority(Property.category(property))
  end

  # Map category atoms to priority numbers
  defp category_to_priority(:custom_property), do: 1
  defp category_to_priority(:shorthands_of_shorthands), do: 1000
  defp category_to_priority(:shorthands_of_longhands), do: 2000
  defp category_to_priority(:longhand_logical), do: 3000
  defp category_to_priority(:longhand_physical), do: 4000

  # ===========================================================================
  # Pseudo Priority
  # ===========================================================================

  @doc """
  Get the priority addition for a pseudo-class or pseudo-element.

  Delegates to `LiveStyle.Pseudo.calculate_priority/1` for compile-time generated lookups.
  For combined pseudo-classes like `:hover:active`, returns the sum of all priorities.
  StyleX behavior: 3000 + 130 + 170 = 3300 for `color` with `:hover:active`.
  """
  @spec get_pseudo_priority(String.t() | nil) :: integer()
  def get_pseudo_priority(selector_suffix), do: Pseudo.calculate_priority(selector_suffix)

  # ===========================================================================
  # At-Rule Priority
  # ===========================================================================

  @doc """
  Get the priority addition for an at-rule.

  Uses binary pattern matching for efficient at-rule detection.
  """
  @spec get_at_rule_priority(String.t() | nil) :: integer()
  def get_at_rule_priority(nil), do: 0
  def get_at_rule_priority(<<"@supports", _rest::binary>>), do: 30
  def get_at_rule_priority(<<"@media", _rest::binary>>), do: 200
  def get_at_rule_priority(<<"@container", _rest::binary>>), do: 300
  def get_at_rule_priority(_), do: 0

  # ===========================================================================
  # Accessors for constants (useful for tests)
  # ===========================================================================

  @doc """
  Returns the pseudo-class priorities map.
  """
  def pseudo_class_priorities, do: Pseudo.priorities()

  @doc """
  Returns the at-rule priorities map.
  """
  def at_rule_priorities, do: @at_rule_priorities

  @doc """
  Returns the pseudo-element base priority.
  """
  def pseudo_element_priority, do: Pseudo.element_priority()
end
