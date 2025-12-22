defmodule LiveStyle.CSS.AtRules do
  @moduledoc false

  # Compiled regex for splitting at-rules on @ symbol
  @at_rule_split_regex ~r/(?=@)/

  @spec wrap(String.t() | nil | [String.t()], String.t()) :: String.t()
  def wrap(nil, css), do: css
  def wrap("", css), do: css

  def wrap(at_rules, css) when is_list(at_rules) do
    at_rules
    |> Enum.sort()
    |> Enum.reduce(css, fn rule, inner -> "#{rule}{#{inner}}" end)
  end

  def wrap(at_rule, css) when is_binary(at_rule) do
    at_rule
    |> split_at_rules()
    |> Enum.sort()
    |> Enum.reduce(css, fn rule, inner -> "#{rule}{#{inner}}" end)
  end

  defp split_at_rules(at_rule) do
    Regex.split(@at_rule_split_regex, at_rule, trim: true)
  end
end
