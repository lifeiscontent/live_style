defmodule LiveStyle.Class.Selector do
  @moduledoc """
  CSS selector parsing for LiveStyle class processing.

  This module handles parsing and decomposition of combined CSS selectors
  that may contain both at-rules and pseudo-classes/elements.

  ## Combined Selector Format

  LiveStyle allows combining at-rules with pseudo-classes in a single string:

      "@media (min-width: 800px):hover"  -> at-rule + pseudo-class
      "@supports (x)@media (y):focus"    -> nested at-rules + pseudo-class

  This module parses these combined selectors into their components.

  ## Examples

      iex> parse_combined("@media (min-width: 800px):hover")
      {":hover", "@media (min-width: 800px)"}

      iex> parse_combined(":hover")
      {":hover", nil}

      iex> parse_combined("@media (x)")
      {nil, "@media (x)"}
  """

  @doc """
  Parse a combined selector that may contain both an at-rule and a pseudo-class.

  Returns `{selector_suffix, at_rule}` where:
  - `selector_suffix` is the pseudo-class/element part (e.g., `:hover`, `::before`)
  - `at_rule` is the at-rule part (e.g., `@media (min-width: 800px)`)

  Either may be nil if not present.

  ## Examples

      iex> parse_combined(":hover")
      {":hover", nil}

      iex> parse_combined("@media (x)")
      {nil, "@media (x)"}

      iex> parse_combined("@media (x):hover")
      {":hover", "@media (x)"}

      iex> parse_combined("@supports (x):focus:active")
      {":focus:active", "@supports (x)"}

      iex> parse_combined("@media (x)@supports (y):hover")
      {":hover", "@media (x)@supports (y)"}
  """
  @spec parse_combined(String.t()) :: {String.t() | nil, String.t() | nil}
  def parse_combined(<<"@", _rest::binary>> = selector) do
    # Find where the pseudo-class starts (first : not inside parentheses)
    case find_pseudo_in_at_rule(selector) do
      nil ->
        # No pseudo-class, just at-rule
        {nil, selector}

      {at_rule, pseudo} ->
        {pseudo, at_rule}
    end
  end

  def parse_combined(selector) do
    # Just a pseudo-class/selector suffix
    {selector, nil}
  end

  @doc """
  Find where the pseudo-class starts in an at-rule selector.

  We need to skip over ALL parentheses to handle nested at-rules like:
  `@media (min-width: 800px)@supports (color: oklch(0 0 0)):hover`

  Returns `{at_rule_part, pseudo_part}` or `nil` if no pseudo-class found.
  """
  @spec find_pseudo_in_at_rule(String.t()) :: {String.t(), String.t()} | nil
  def find_pseudo_in_at_rule(selector) do
    # Find the LAST closing paren - all at-rules must be before the pseudo-class
    find_last_paren_and_pseudo(selector, byte_size(selector) - 1)
  end

  # Private helpers for finding pseudo-class position

  defp find_last_paren_and_pseudo(_selector, pos) when pos < 0, do: nil

  defp find_last_paren_and_pseudo(selector, pos) do
    char = :binary.part(selector, pos, 1)

    if char == ")" do
      check_after_paren(selector, pos)
    else
      # Not a paren, keep looking backward
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
        # Another at-rule follows, keep looking backward
        find_last_paren_and_pseudo(selector, pos - 1)

      "" ->
        # End of string, no pseudo-class
        nil

      _ ->
        # Something else, keep looking backward
        find_last_paren_and_pseudo(selector, pos - 1)
    end
  end
end
