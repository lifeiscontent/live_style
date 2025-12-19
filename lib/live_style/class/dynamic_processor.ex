defmodule LiveStyle.Class.DynamicProcessor do
  @moduledoc """
  Processes dynamic CSS declarations into atomic classes.

  Dynamic classes use CSS variables that are set at runtime via inline styles.
  For example, a dynamic opacity class generates CSS like:
  `.x1234 { opacity: var(--x-opacity); }`

  The actual value is then set at runtime: `style="--x-opacity: 0.5"`

  ## Responsibilities

  - Converting property names to CSS variable references
  - Generating atomic classes that use var() values
  - Building the class string for dynamic classes
  """

  alias LiveStyle.{Hash, Value}

  @doc """
  Processes a list of property atoms into dynamic atomic class entries.

  Returns a tuple of `{atomic_classes, class_string}` where:
  - `atomic_classes` is a map of CSS property names to class entries
  - `class_string` is the space-separated string of all class names

  ## Example

      iex> process([:opacity, :color])
      {
        %{
          "opacity" => %{class: "x1234", value: "var(--x-opacity)", var: "--x-opacity"},
          "color" => %{class: "x5678", value: "var(--x-color)", var: "--x-color"}
        },
        "x1234 x5678"
      }
  """
  @spec process([atom()]) :: {map(), String.t()}
  def process(props) do
    # For dynamic rules, the CSS value is var(--x-prop)
    # This allows runtime values to be set via inline style
    atomic =
      Map.new(props, fn prop ->
        css_prop = Value.to_css_property(prop)
        css_var = "--x-#{css_prop}"
        css_value = "var(#{css_var})"
        class_name = Hash.atomic_class(css_prop, css_value, nil, nil, nil)
        {css_prop, %{class: class_name, value: css_value, var: css_var}}
      end)

    class_string =
      atomic
      |> Map.values()
      |> Enum.map_join(" ", & &1.class)

    {atomic, class_string}
  end
end
