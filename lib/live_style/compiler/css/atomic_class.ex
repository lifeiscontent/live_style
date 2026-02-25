defmodule LiveStyle.Compiler.CSS.AtomicClass do
  @moduledoc false
  # Internal module for CSS class generation helpers.

  alias LiveStyle.Compiler.CSS.AtRules
  alias LiveStyle.RTL
  alias LiveStyle.Selector

  @doc false
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
    selector = Selector.build_atomic_class_selector(class_name, selector_suffix, at_rule)

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
    selector = Selector.build_atomic_class_selector(class_name, selector_suffix, at_rule)

    # Generate LTR and RTL pairs for each fallback value
    pairs =
      Enum.map(values, fn val ->
        ltr = RTL.generate_ltr(property, val)
        rtl = RTL.generate_rtl(property, val)
        {ltr, rtl}
      end)

    ltr_decls = Enum.map_join(pairs, ";", fn {{p, v}, _} -> "#{p}:#{v}" end)
    ltr_css = wrap_in_at_rules(at_rule, "#{selector}{#{ltr_decls}}")

    # Generate RTL CSS if any value differs in RTL
    rtl_decls =
      Enum.map_join(pairs, ";", fn {{lp, lv}, rtl} ->
        {rp, rv} = rtl || {lp, lv}
        "#{rp}:#{rv}"
      end)

    rtl_css =
      if rtl_decls == ltr_decls do
        nil
      else
        wrap_in_at_rules(at_rule, "html[dir=\"rtl\"] #{selector}{#{rtl_decls}}")
      end

    {ltr_css, rtl_css}
  end

  @doc false
  @spec wrap_in_at_rules(String.t() | nil, String.t()) :: String.t()
  def wrap_in_at_rules(at_rule, css), do: AtRules.wrap(at_rule, css)
end
