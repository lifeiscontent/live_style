defmodule LiveStyle.Shorthand.Strategy.ExpandToLonghands do
  @moduledoc """
  Expands shorthand properties to their constituent longhands.

  This strategy fully expands shorthand properties to their individual
  longhand properties. For example, `margin: "10px 20px"` becomes
  four separate margin properties.

  More verbose CSS output but predictable specificity.

  ## Example

      # Input
      margin: "10px 20px"

      # Output expands to longhands
      margin_top: "10px"
      margin_right: "20px"
      margin_bottom: "10px"
      margin_left: "20px"
  """

  @behaviour LiveStyle.Shorthand.Strategy

  alias LiveStyle.Shorthand.Strategy

  @impl true
  def expand_declaration(key, value, opts) do
    css_property = LiveStyle.to_css_property(key)

    case Strategy.get_expansion_fn(css_property, opts) do
      nil ->
        Strategy.passthrough(key, value)

      _expansion_fn ->
        LiveStyle.Shorthand.expand_to_longhands(css_property, value)
    end
  end

  @impl true
  def expand_shorthand_conditions(key, css_property, conditions, opts) do
    case Strategy.get_expansion_fn(css_property, opts) do
      nil ->
        Strategy.passthrough_conditions(key, conditions)

      _expansion_fn ->
        expand_conditions_to_longhands(key, css_property, conditions)
    end
  end

  defp expand_conditions_to_longhands(key, css_property, conditions) do
    longhand_props = LiveStyle.Shorthand.get_longhand_properties(css_property)

    if Enum.empty?(longhand_props) do
      Strategy.passthrough_conditions(key, conditions)
    else
      do_expand_conditions(css_property, conditions)
    end
  end

  defp do_expand_conditions(css_property, conditions) do
    conditions
    |> Enum.flat_map(&expand_condition_to_props(css_property, &1))
    |> Enum.group_by(fn {prop, _} -> prop end, fn {_, cond_map} -> cond_map end)
    |> Enum.map(&merge_condition_maps/1)
  end

  defp expand_condition_to_props(css_property, {condition, value}) do
    expanded = LiveStyle.Shorthand.expand_to_longhands(css_property, value)
    Enum.map(expanded, fn {prop, val} -> {prop, %{condition => val}} end)
  end

  defp merge_condition_maps({prop, cond_maps}) do
    merged = Enum.reduce(cond_maps, %{}, &Map.merge(&2, &1))
    {prop, merged}
  end
end
