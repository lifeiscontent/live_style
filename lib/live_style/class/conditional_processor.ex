defmodule LiveStyle.Class.ConditionalProcessor do
  @moduledoc """
  Processes conditional CSS declarations into atomic classes.

  This module handles declarations with conditional values like pseudo-classes,
  media queries, and other at-rules. For example:
  `%{color: %{:default => "red", ":hover" => "blue", "@media (min-width: 768px)" => "green"}}`

  ## Responsibilities

  - Expanding shorthand properties for conditional values
  - Applying StyleX's "last media query wins" transformation
  - Flattening nested conditional maps
  - Generating atomic class entries for each condition
  """

  alias LiveStyle.Class.Conditional
  alias LiveStyle.CSS.AtomicClass
  alias LiveStyle.CSS.ConditionSelector
  alias LiveStyle.{Hash, Priority, Value}
  alias LiveStyle.MediaQuery.Transform, as: MediaQueryTransform
  alias LiveStyle.ShorthandBehavior

  @doc """
  Processes a list of conditional declarations into atomic class entries.

  Returns a map where each CSS property maps to a `%{classes: ...}` entry
  containing the class entries for each condition.

  ## Example

      iex> process([{:color, %{:default => "red", ":hover" => "blue"}}])
      %{
        "color" => %{
          classes: %{
            :default => %{class: "x1234", value: "red", ...},
            ":hover" => %{class: "x5678", value: "blue", ...}
          }
        }
      }
  """
  @spec process(list(), keyword()) :: map()
  def process(declarations, _opts \\ []) do
    declarations
    |> Enum.flat_map(fn {prop, value_map} ->
      # Convert key to CSS string at boundary
      css_prop = Value.to_css_property(prop)

      # Use style resolution for conditional properties
      ShorthandBehavior.expand_shorthand_conditions(css_prop, value_map)
    end)
    |> Enum.flat_map(&process_expanded/1)
    |> Map.new()
  end

  # Process an expanded conditional declaration
  defp process_expanded({css_prop, value_map}) do
    # Apply StyleX's "last media query wins" transformation
    transformed_value_map = MediaQueryTransform.transform(value_map)

    # Flatten nested conditional maps into a list of {selector, value} tuples
    flattened = Conditional.flatten(transformed_value_map, nil)

    # Process each flattened condition
    classes =
      flattened
      |> Enum.reject(fn {_selector, v} -> is_nil(v) end)
      |> Enum.map(fn {selector, css_value} ->
        build_class_entry(css_prop, selector, css_value)
      end)
      |> Map.new()

    [{css_prop, %{classes: classes}}]
  end

  # Build a class entry for the default value (no selector suffix)
  defp build_class_entry(css_prop, nil, css_value) do
    css_value_str = Value.to_css(css_value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value_str, nil, nil, nil)

    {ltr_css, rtl_css} =
      AtomicClass.generate_metadata(class_name, css_prop, css_value_str, nil, nil)

    priority = Priority.calculate(css_prop, nil, nil)

    {:default,
     %{
       class: class_name,
       value: css_value_str,
       selector_suffix: nil,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end

  # Build a class entry for a conditional value (with selector or at-rule)
  defp build_class_entry(css_prop, selector, css_value) do
    css_value_str = Value.to_css(css_value, css_prop)
    {selector_suffix, at_rule} = ConditionSelector.parse_combined(selector)
    class_name = Hash.atomic_class(css_prop, css_value_str, nil, selector_suffix, at_rule)

    {ltr_css, rtl_css} =
      AtomicClass.generate_metadata(class_name, css_prop, css_value_str, selector_suffix, at_rule)

    priority = Priority.calculate(css_prop, selector_suffix, at_rule)

    {selector,
     %{
       class: class_name,
       value: css_value_str,
       selector_suffix: selector_suffix,
       at_rule: at_rule,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end
end
