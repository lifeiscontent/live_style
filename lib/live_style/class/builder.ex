defmodule LiveStyle.Class.Builder do
  @moduledoc false
  # Shared class entry building logic for processors.
  # Implements StyleX model: pre-build full CSS at compile time.
  # Config (use_css_layers) is read at compile time via Application.compile_env.

  alias LiveStyle.Compiler.CSS.{AtomicClass, Priority}
  alias LiveStyle.{CSSValue, Hash, RTL, Selector}

  @doc """
  Creates a class entry for an atomic CSS class with pre-built CSS.

  Returns a keyword list containing:
    * `:class` - The generated class name
    * `:priority` - Priority for ordering
    * `:ltr` - Pre-built LTR CSS rule string
    * `:rtl` - Pre-built RTL CSS rule string (nil if no RTL needed)
  """
  @spec create_entry(String.t(), any(), keyword()) :: keyword()
  def create_entry(css_prop, value, opts \\ []) do
    selector = Keyword.get(opts, :selector)
    at_rule = Keyword.get(opts, :at_rule)

    css_value = CSSValue.to_css(value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value, selector, nil, at_rule)
    priority = Priority.calculate(css_prop, selector, at_rule)

    # Detect if selector is a pseudo-element (starts with "::")
    pseudo_element = if selector && String.starts_with?(selector, "::"), do: selector, else: nil
    selector_suffix = if pseudo_element, do: nil, else: selector

    # Pre-build full CSS rules
    {ltr, rtl} =
      build_css(class_name, css_prop, css_value, selector_suffix, pseudo_element, at_rule)

    [class: class_name, priority: priority, ltr: ltr, rtl: rtl]
  end

  @doc """
  Creates a class entry for fallback values (multiple CSS declarations).
  """
  @spec create_entry_with_fallbacks(String.t(), String.t(), list(), keyword()) :: keyword()
  def create_entry_with_fallbacks(css_prop, class_name, fallback_values, opts \\ []) do
    selector = Keyword.get(opts, :selector)
    at_rule = Keyword.get(opts, :at_rule)
    priority = Priority.calculate(css_prop, selector, at_rule)

    pseudo_element = if selector && String.starts_with?(selector, "::"), do: selector, else: nil
    selector_suffix = if pseudo_element, do: nil, else: selector

    {ltr, rtl} =
      build_fallback_css(
        class_name,
        css_prop,
        fallback_values,
        selector_suffix,
        pseudo_element,
        at_rule
      )

    [class: class_name, priority: priority, ltr: ltr, rtl: rtl]
  end

  # Build full CSS rule strings for a single value
  defp build_css(class_name, property, value, selector_suffix, pseudo_element, at_rule) do
    {ltr_prop, ltr_val} = RTL.generate_ltr(property, value)

    selector =
      Selector.build_atomic_rule_selector(class_name, selector_suffix, pseudo_element, at_rule)

    ltr_decl = LiveStyle.Config.apply_prefix_css(ltr_prop, ltr_val)
    ltr_inner = "#{selector}{#{ltr_decl}}"
    ltr = AtomicClass.wrap_in_at_rules(at_rule, ltr_inner)

    rtl =
      case RTL.generate_rtl(property, value) do
        nil ->
          nil

        {rtl_prop, rtl_val} ->
          rtl_decl = LiveStyle.Config.apply_prefix_css(rtl_prop, rtl_val)
          rtl_selector = Selector.prefix_rtl(selector)
          rtl_inner = "#{rtl_selector}{#{rtl_decl}}"
          AtomicClass.wrap_in_at_rules(at_rule, rtl_inner)
      end

    {ltr, rtl}
  end

  # Build full CSS rule strings for fallback values
  defp build_fallback_css(
         class_name,
         property,
         fallback_values,
         selector_suffix,
         pseudo_element,
         at_rule
       ) do
    selector =
      Selector.build_atomic_rule_selector(class_name, selector_suffix, pseudo_element, at_rule)

    ltr_decls =
      Enum.map_join(fallback_values, ";", fn val ->
        {ltr_prop, ltr_val} = RTL.generate_ltr(property, val)
        LiveStyle.Config.apply_prefix_css(ltr_prop, ltr_val)
      end)

    ltr_inner = "#{selector}{#{ltr_decls}}"
    ltr = AtomicClass.wrap_in_at_rules(at_rule, ltr_inner)

    {ltr, nil}
  end
end
