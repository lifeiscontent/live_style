defmodule LiveStyle.Selector.Condition do
  @moduledoc false
  # Internal module for parsing combined StyleX condition selectors.
  #
  # Examples:
  # - ":hover" -> {":hover", nil}
  # - "@media (min-width: 800px)" -> {nil, "@media (min-width: 800px)"}
  # - "@media (min-width: 800px)@supports (color: oklch(0 0 0)):hover" ->
  #   {":hover", "@media (min-width: 800px)@supports (color: oklch(0 0 0))"}

  @doc false
  @spec parse_combined(String.t()) :: {String.t() | nil, String.t() | nil}
  def parse_combined(<<"@", _rest::binary>> = selector) do
    case find_pseudo_in_at_rule(selector) do
      nil ->
        {nil, selector}

      {at_rule, pseudo} ->
        {pseudo, at_rule}
    end
  end

  def parse_combined(selector) do
    # Check if a pseudo-selector is followed by an at-rule
    # e.g., ":not([data-theme])@media (prefers-color-scheme: dark)"
    case find_at_rule_after_pseudo(selector) do
      nil ->
        {selector, nil}

      {pseudo, at_rule} ->
        {pseudo, at_rule}
    end
  end

  # Find @-rule that follows a pseudo-selector
  # e.g., ":hover@media ..." -> {":hover", "@media ..."}
  defp find_at_rule_after_pseudo(selector) do
    case :binary.match(selector, "@") do
      :nomatch ->
        nil

      {pos, _len} ->
        pseudo = binary_part(selector, 0, pos)
        at_rule = binary_part(selector, pos, byte_size(selector) - pos)
        {pseudo, at_rule}
    end
  end

  defp find_pseudo_in_at_rule(selector) do
    find_last_paren_and_pseudo(selector, byte_size(selector) - 1)
  end

  defp find_last_paren_and_pseudo(_selector, pos) when pos < 0, do: nil

  defp find_last_paren_and_pseudo(selector, pos) do
    char = :binary.part(selector, pos, 1)

    if char == ")" do
      check_after_paren(selector, pos)
    else
      find_last_paren_and_pseudo(selector, pos - 1)
    end
  end

  defp check_after_paren(selector, pos) do
    after_paren = binary_part(selector, pos + 1, byte_size(selector) - pos - 1)

    case after_paren do
      <<":", _::binary>> ->
        at_rule = binary_part(selector, 0, pos + 1)
        {at_rule, after_paren}

      <<"@", _::binary>> ->
        find_last_paren_and_pseudo(selector, pos - 1)

      "" ->
        nil

      _ ->
        find_last_paren_and_pseudo(selector, pos - 1)
    end
  end
end
