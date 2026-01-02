defmodule LiveStyle.Class.Processor.Dynamic do
  @moduledoc """
  Processes dynamic CSS declarations into atomic classes.

  Dynamic classes use CSS variables that are set at runtime via inline styles.
  For example, with the default prefix "x", a dynamic opacity class generates CSS like:
  `.x1234 { opacity: var(--x-opacity); }`

  The actual value is then set at runtime: `style="--x-opacity: 0.5"`

  The CSS variable prefix is derived from the configured `class_name_prefix`.
  """

  alias LiveStyle.Class.Builder
  alias LiveStyle.{Config, CSSValue, Hash}

  @doc """
  Processes a list of property atoms into dynamic atomic class entries.

  Returns a tuple of `{atomic_classes, class_string}` where:
  - `atomic_classes` is a list of `{css_prop, entry}` tuples with pre-built CSS
  - `class_string` is the space-separated string of all class names
  """
  @spec transform([atom()]) :: {list(), String.t()}
  def transform(props) do
    # For dynamic rules, the CSS value is var(--<prefix>-prop)
    # This allows runtime values to be set via inline style
    prefix = Config.class_name_prefix()

    atomic =
      Enum.map(props, fn prop ->
        css_prop = CSSValue.to_css_property(prop)
        css_var = "--#{prefix}-#{css_prop}"
        css_value = "var(#{css_var})"

        # Use Builder to create entry with pre-built CSS
        entry = Builder.create_entry(css_prop, css_value)

        # Override class name to use the var-based hash
        class_name = Hash.atomic_class(css_prop, css_value, nil, nil, nil)
        entry = Keyword.put(entry, :class, class_name)

        # Add var reference for runtime use
        entry = Keyword.put(entry, :var, css_var)

        {css_prop, entry}
      end)

    class_string =
      atomic
      |> Enum.map_join(" ", fn {_prop, entry} -> Keyword.get(entry, :class) end)

    {atomic, class_string}
  end
end
