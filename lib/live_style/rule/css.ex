defmodule LiveStyle.Rule.CSS do
  @moduledoc """
  CSS rule generation helpers for LiveStyle.

  This module handles the generation of CSS rule strings including:
  - LTR/RTL CSS generation
  - At-rule wrapping (@media, @supports)
  - Selector building with specificity bumping
  - Array fallback handling
  """

  alias LiveStyle.Hash
  alias LiveStyle.RTL

  @doc """
  Generate StyleX-compatible CSS rule metadata (ltr, rtl strings).

  Returns a tuple of `{ltr_css, rtl_css}` where rtl_css may be nil.

  ## Examples

      iex> generate_css_rule_metadata("x123", "color", "red", nil, nil)
      {".x123{color:red}", nil}

      iex> generate_css_rule_metadata("x123", "color", "red", ":hover", nil)
      {".x123:hover{color:red}", nil}
  """
  @spec generate_metadata(
          String.t(),
          String.t(),
          String.t() | list(),
          String.t() | nil,
          String.t() | nil
        ) ::
          {String.t(), String.t() | nil}
  def generate_metadata(class_name, property, value, selector_suffix, at_rule)
      when is_binary(value) do
    # Generate LTR CSS
    {ltr_prop, ltr_val} = RTL.generate_ltr(property, value)
    ltr_decl = "#{ltr_prop}:#{ltr_val}"

    # Build selector
    selector = build_selector(class_name, selector_suffix, at_rule)

    ltr_css = "#{selector}{#{ltr_decl}}"

    # Generate RTL CSS (may be nil if no RTL transformation needed)
    rtl_css =
      case RTL.generate_rtl(property, value) do
        nil ->
          nil

        {rtl_prop, rtl_val} ->
          rtl_decl = "#{rtl_prop}:#{rtl_val}"
          "html[dir=\"rtl\"] #{selector}{#{rtl_decl}}"
      end

    # Wrap in at-rule if present (handles nested at-rules)
    ltr_css = wrap_in_at_rules(at_rule, ltr_css)
    rtl_css = if rtl_css, do: wrap_in_at_rules(at_rule, rtl_css), else: nil

    {ltr_css, rtl_css}
  end

  # Handle array fallback values (from css_fallback / firstThatWorks)
  def generate_metadata(class_name, property, values, selector_suffix, at_rule)
      when is_list(values) do
    # Build declarations for all fallback values
    # Order preserved: first value is the preferred one, subsequent values are fallbacks
    # CSS applies in order, so last declaration wins if supported
    decls =
      values
      |> Enum.map(fn val ->
        {ltr_prop, ltr_val} = RTL.generate_ltr(property, val)
        "#{ltr_prop}:#{ltr_val}"
      end)
      |> Enum.join(";")

    selector = build_selector(class_name, selector_suffix, at_rule)
    ltr_css = "#{selector}{#{decls}}"

    # Wrap in at-rule if present (handles nested at-rules)
    ltr_css = wrap_in_at_rules(at_rule, ltr_css)

    # RTL handling for arrays is more complex, skip for now
    {ltr_css, nil}
  end

  @doc """
  Build CSS selector with optional pseudo-class/element and specificity bumping.

  StyleX doubles the class selector for specificity when:
  - at-rules are present (@media, @supports, etc.)
  - contextual selectors are used (:where(...), when.ancestor, etc.)
  """
  @spec build_selector(String.t(), String.t() | nil, String.t() | nil) :: String.t()
  def build_selector(class_name, selector_suffix, at_rule) do
    needs_specificity_bump = at_rule != nil or contextual_selector?(selector_suffix)

    base =
      if needs_specificity_bump do
        ".#{class_name}.#{class_name}"
      else
        ".#{class_name}"
      end

    if selector_suffix do
      # Sort pseudo-classes alphabetically (StyleX behavior)
      # e.g., ":hover:active" becomes ":active:hover"
      # Note: Complex selectors like :where(...) are passed through unchanged
      sorted_suffix = Hash.sort_combined_pseudos(selector_suffix)
      "#{base}#{sorted_suffix}"
    else
      base
    end
  end

  @doc """
  Wrap CSS in nested at-rules.

  StyleX sorts at-rules alphabetically, then wraps left-to-right.
  Input: "@media (min-width: 800px)@supports (color: oklch(0 0 0))"
  Output: "@supports (color: oklch(0 0 0)){@media (min-width: 800px){...}}"
  (because @media < @supports alphabetically, @supports ends up as outer wrapper)
  """
  @spec wrap_in_at_rules(String.t() | nil, String.t()) :: String.t()
  def wrap_in_at_rules(nil, css), do: css
  def wrap_in_at_rules("", css), do: css

  def wrap_in_at_rules(at_rule, css) do
    # Split combined at-rules into individual rules
    # @media (x)@supports (y) -> ["@media (x)", "@supports (y)"]
    at_rules = split_at_rules(at_rule)

    # Sort alphabetically (StyleX behavior) and wrap left-to-right
    # ["@media (x)", "@supports (y)"] sorted stays the same
    # reduce wraps: @supports{@media{css}} (last alphabetically = outermost)
    at_rules
    |> Enum.sort()
    |> Enum.reduce(css, fn rule, inner ->
      "#{rule}{#{inner}}"
    end)
  end

  @doc """
  Split combined at-rules into individual rules.

  ## Examples

      iex> split_at_rules("@media (min-width: 800px)@supports (color: oklch(0 0 0))")
      ["@media (min-width: 800px)", "@supports (color: oklch(0 0 0))"]
  """
  @spec split_at_rules(String.t()) :: list(String.t())
  def split_at_rules(at_rule) do
    # Use regex to split at @ boundaries, preserving the @ symbol
    Regex.split(~r/(?=@)/, at_rule, trim: true)
  end

  @doc """
  Check if selector_suffix is a contextual selector.

  Contextual selectors include :where, :is, :has, or :not with complex content.
  """
  @spec contextual_selector?(String.t() | nil) :: boolean()
  def contextual_selector?(nil), do: false

  def contextual_selector?(suffix) when is_binary(suffix) do
    String.starts_with?(suffix, ":where(") or
      String.starts_with?(suffix, ":is(") or
      String.starts_with?(suffix, ":has(") or
      (String.starts_with?(suffix, ":not(") and String.contains?(suffix, " "))
  end
end
