defmodule LiveStyle.Compiler.Class.Processor.Conditional do
  @moduledoc """
  Processes conditional CSS declarations into atomic classes.

  This module handles declarations with conditional values like pseudo-classes,
  media queries, and other at-rules. For example:
  `[color: [default: "red", ":hover": "blue", "@media (min-width: 768px)": "green"]]`

  ## Responsibilities

  - Expanding shorthand properties for conditional values
  - Applying StyleX's "last media query wins" transformation
  - Flattening nested conditional lists
  - Generating atomic class entries for each condition
  """

  alias LiveStyle.Compiler.Class.{Builder, Conditional}
  alias LiveStyle.{CSSValue, ShorthandBehavior}
  alias LiveStyle.MediaQuery.Transform, as: MediaQueryTransform
  alias LiveStyle.Selector.Condition, as: ConditionSelector

  @doc """
  Processes a list of conditional declarations into atomic class entries.

  Returns a list of `{css_prop, %{classes: [...]}}` tuples containing
  the class entries for each condition.

  ## Example

      iex> process([{:color, [default: "red", ":hover": "blue"]}])
      [
        {"color", %{
          classes: [
            {:default, %{class: "x1234", value: "red", ...}},
            {":hover", %{class: "x5678", value: "blue", ...}}
          ]
        }}
      ]
  """
  @spec process(list(), keyword()) :: list()
  def process(declarations, _opts \\ []) do
    declarations
    |> Enum.flat_map(fn {prop, conditions} ->
      # Convert key to CSS string at boundary
      css_prop = CSSValue.to_css_property(prop)

      # Use style resolution for conditional properties
      ShorthandBehavior.expand_shorthand_conditions(css_prop, conditions)
    end)
    |> Enum.flat_map(&process_expanded/1)
  end

  # Process an expanded conditional declaration
  defp process_expanded({css_prop, conditions}) do
    # Apply StyleX's "last media query wins" transformation
    transformed = MediaQueryTransform.transform(conditions)

    # Flatten nested conditional lists into a list of {selector, value} tuples
    flattened = Conditional.flatten(transformed, nil)

    # Process each flattened condition
    classes =
      flattened
      |> Enum.reject(fn {_selector, v} -> is_nil(v) end)
      |> Enum.map(fn {selector, css_value} ->
        build_class_entry(css_prop, selector, css_value)
      end)

    [{css_prop, [classes: classes]}]
  end

  # Build a class entry for the default value (no selector suffix)
  defp build_class_entry(css_prop, nil, css_value) do
    entry = Builder.build(css_prop, css_value)
    {:default, Keyword.put(entry, :selector_suffix, nil)}
  end

  # Build a class entry for a conditional value (with selector or at-rule)
  defp build_class_entry(css_prop, selector, css_value) do
    {selector_suffix, at_rule} = ConditionSelector.parse_combined(selector)
    entry = Builder.build(css_prop, css_value, selector: selector_suffix, at_rule: at_rule)

    {selector,
     entry
     |> Keyword.put(:selector_suffix, selector_suffix)
     |> Keyword.put(:at_rule, at_rule)}
  end
end
