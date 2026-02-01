defmodule LiveStyle.Compiler.CSS.AtRules do
  @moduledoc false

  # Compiled regex for splitting at-rules on @ symbol
  @at_rule_split_regex ~r/(?=@)/

  # Priority determines wrap order (lower number = wrapped first = innermost in CSS)
  # Higher number = wrapped last = outermost in CSS
  #
  # Example: For `@starting-style@media (min-width: 640px)`:
  # - @starting-style has priority 10, @media has priority 30
  # - Sorted ascending: [@starting-style, @media...]
  # - Reduce wraps in order: first @starting-style{css}, then @media{@starting-style{css}}
  # - Result: @starting-style is INSIDE @media (correct behavior)
  @at_rule_wrap_priority %{
    "@starting-style" => 10,
    "@container" => 20,
    "@media" => 30,
    "@supports" => 40,
    "@layer" => 50
  }

  @spec wrap(String.t() | nil | [String.t()], String.t()) :: String.t()
  def wrap(nil, css), do: css
  def wrap("", css), do: css

  def wrap(at_rules, css) when is_list(at_rules) do
    at_rules
    |> Enum.sort_by(&at_rule_sort_key/1, :asc)
    |> Enum.reduce(css, fn rule, inner -> "#{rule}{#{inner}}" end)
  end

  def wrap(at_rule, css) when is_binary(at_rule) do
    at_rule
    |> split_at_rules()
    |> Enum.sort_by(&at_rule_sort_key/1, :asc)
    |> Enum.reduce(css, fn rule, inner -> "#{rule}{#{inner}}" end)
  end

  defp split_at_rules(at_rule) do
    Regex.split(@at_rule_split_regex, at_rule, trim: true)
  end

  defp at_rule_sort_key(at_rule) do
    base = at_rule_base_name(at_rule)
    {Map.get(@at_rule_wrap_priority, base, 50), at_rule}
  end

  defp at_rule_base_name(at_rule) do
    at_rule
    |> String.split(~r/[\s(]/, parts: 2)
    |> List.first()
  end
end
