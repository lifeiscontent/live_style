defmodule LiveStyle.Compiler.Class.Builder do
  @moduledoc false
  # Shared class entry building logic for processors.

  alias LiveStyle.Compiler.CSS.{AtomicClass, Priority}
  alias LiveStyle.{CSSValue, Hash}

  @doc """
  Builds a class entry map for an atomic CSS class.

  Takes the CSS property, value, and optional selector/at-rule parameters,
  and returns a map with all the metadata needed for the class.

  ## Parameters

    * `css_prop` - The CSS property name (string)
    * `value` - The raw value (will be converted via CSSValue.to_css)
    * `opts` - Keyword list of options:
      * `:selector` - Optional selector suffix (e.g., "::before", ":hover")
      * `:at_rule` - Optional at-rule (e.g., "@media (min-width: 768px)")

  ## Returns

  A map containing:
    * `:class` - The generated class name
    * `:value` - The CSS value string
    * `:ltr` - LTR CSS metadata
    * `:rtl` - RTL CSS metadata
    * `:priority` - Priority for ordering
  """
  @spec build(String.t(), any(), keyword()) :: map()
  def build(css_prop, value, opts \\ []) do
    selector = Keyword.get(opts, :selector)
    at_rule = Keyword.get(opts, :at_rule)

    css_value = CSSValue.to_css(value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value, selector, nil, at_rule)

    {ltr_css, rtl_css} =
      AtomicClass.generate_metadata(class_name, css_prop, css_value, selector, at_rule)

    priority = Priority.calculate(css_prop, selector, at_rule)

    %{
      class: class_name,
      value: css_value,
      ltr: ltr_css,
      rtl: rtl_css,
      priority: priority
    }
  end
end
