defmodule LiveStyle.Priority do
  @moduledoc false
  # Internal module for CSS rule priority calculation.

  alias LiveStyle.Property
  alias LiveStyle.Pseudo

  @doc false
  @spec calculate(String.t(), String.t() | nil, String.t() | nil) :: integer()
  def calculate(property, selector_suffix, at_rule) do
    property_priority = get_property_priority(property)
    pseudo_priority = get_pseudo_priority(selector_suffix)
    at_rule_priority = get_at_rule_priority(at_rule)

    property_priority + pseudo_priority + at_rule_priority
  end

  @doc false
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

  @doc false
  @spec get_pseudo_priority(String.t() | nil) :: integer()
  def get_pseudo_priority(selector_suffix), do: Pseudo.calculate_priority(selector_suffix)

  @doc false
  @spec get_at_rule_priority(String.t() | nil) :: integer()
  def get_at_rule_priority(nil), do: 0
  def get_at_rule_priority(<<"@starting-style", _rest::binary>>), do: 20
  def get_at_rule_priority(<<"@supports", _rest::binary>>), do: 30
  def get_at_rule_priority(<<"@media", _rest::binary>>), do: 200
  def get_at_rule_priority(<<"@container", _rest::binary>>), do: 300
  def get_at_rule_priority(_), do: 0
end
