defmodule LiveStyle.Types do
  @moduledoc """
  Type helpers for CSS custom properties.

  These functions wrap variable values to declare their CSS type, enabling
  features like animating gradients or capturing computed values.

  When a typed variable is defined with `css_vars`, LiveStyle generates a
  CSS `@property` rule that registers the variable's type with the browser.

  ## Example

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens
        import LiveStyle.Types

        css_vars :color,
          primary: color("black"),
          accent: color(%{default: "blue", "@media (prefers-color-scheme: dark)": "lightblue"})

        css_vars :animation,
          angle: angle("0deg")
      end

  This generates:

      @property --v1234567 {
        syntax: '<color>';
        inherits: true;
        initial-value: black;
      }

  ## Supported Types

  - `angle/1` - CSS `<angle>` values (deg, rad, turn, etc.)
  - `color/1` - CSS `<color>` values
  - `image/1` - CSS `<image>` values (url, gradients, etc.)
  - `integer/1` - CSS `<integer>` values
  - `length/1` - CSS `<length>` values (px, rem, em, etc.)
  - `length_percentage/1` - CSS `<length-percentage>` values
  - `number/1` - CSS `<number>` values (floating point)
  - `percentage/1` - CSS `<percentage>` values
  - `resolution/1` - CSS `<resolution>` values (dpi, dppx, etc.)
  - `time/1` - CSS `<time>` values (s, ms)
  - `transform_function/1` - CSS `<transform-function>` values
  - `transform_list/1` - CSS `<transform-list>` values
  - `url/1` - CSS `<url>` values

  ## Use Cases

  ### Animating Gradients

  Normally gradients cannot be animated. With typed angle variables, you can:

      css_vars :anim,
        angle: angle("0deg")

      # In a component:
      css_keyframes :rotate,
        from: %{css_var(:anim_angle) => "0deg"},
        to: %{css_var(:anim_angle) => "360deg"}

      css_rule :gradient,
        background_image: "conic-gradient(from \#{css_var({MyApp.Tokens, :anim, :angle})}, red, blue)",
        animation: "\#{css_keyframes(:rotate)} 10s linear infinite"

  ### Simulating round()

  Integer types discard fractional values:

      css_vars :layout,
        columns: integer(3)

      # Math.floor: calc(16 / 9) -> 1
      # Math.round: calc((16 / 9) + 0.5) -> 2
  """

  @type typed_value :: %{
          optional(:inherits) => boolean(),
          __type__: :typed_var,
          syntax: String.t(),
          value: term()
        }

  # Type definitions: {function_name, css_syntax, doc_examples}
  @simple_types [
    {:color, "<color>",
     """
     Declares a CSS `<color>` type for a variable.

     Enables color interpolation in animations and transitions.

     ## Examples

         color("black")
         color("#ff0000")
         color("rgb(255, 0, 0)")
         color({default: "black", "@media (prefers-color-scheme: dark)": "white"})
     """},
    {:length, "<length>",
     """
     Declares a CSS `<length>` type for a variable.

     Enables length interpolation and capturing computed values like `1em`.

     ## Examples

         length("4px")
         length("1rem")
         length("1em")
         length({default: "8px", "@media (min-width: 768px)": "16px"})
     """},
    {:angle, "<angle>",
     """
     Declares a CSS `<angle>` type for a variable.

     Enables angle interpolation - useful for animating gradients.

     ## Examples

         angle("0deg")
         angle("45deg")
         angle("0.5turn")
     """},
    {:time, "<time>",
     """
     Declares a CSS `<time>` type for a variable.

     For duration values in animations and transitions.

     ## Examples

         time("0.5s")
         time("300ms")
     """},
    {:percentage, "<percentage>",
     """
     Declares a CSS `<percentage>` type for a variable.

     ## Examples

         percentage("50%")
         percentage("100%")
     """},
    {:url, "<url>",
     """
     Declares a CSS `<url>` type for a variable.

     ## Examples

         url("url(#image)")
         url("url(https://example.com/image.png)")
     """},
    {:image, "<image>",
     """
     Declares a CSS `<image>` type for a variable.

     ## Examples

         image("url(#image)")
         image("linear-gradient(red, blue)")
     """},
    {:resolution, "<resolution>",
     """
     Declares a CSS `<resolution>` type for a variable.

     ## Examples

         resolution("96dpi")
         resolution("2dppx")
     """},
    {:length_percentage, "<length-percentage>",
     """
     Declares a CSS `<length-percentage>` type for a variable.

     Accepts either length or percentage values.

     ## Examples

         length_percentage("50%")
         length_percentage("100px")
     """},
    {:transform_function, "<transform-function>",
     """
     Declares a CSS `<transform-function>` type for a variable.

     ## Examples

         transform_function("translateX(10px)")
         transform_function("rotate(45deg)")
     """},
    {:transform_list, "<transform-list>",
     """
     Declares a CSS `<transform-list>` type for a variable.

     ## Examples

         transform_list("translateX(10px) rotate(45deg)")
     """}
  ]

  # Generate simple type functions
  for {name, syntax, doc} <- @simple_types do
    @doc doc
    @spec unquote(name)(String.t() | map()) :: typed_value()
    def unquote(name)(value) do
      %{__type__: :typed_var, syntax: unquote(syntax), value: value}
    end
  end

  @doc """
  Declares a CSS `<integer>` type for a variable.

  Values are cast to integers, discarding fractional parts.
  Useful for simulating `round()` or `floor()`.

  ## Examples

      integer(3)
      integer("3")
  """
  @spec integer(integer() | String.t() | map()) :: typed_value()
  def integer(value) when is_integer(value) do
    %{__type__: :typed_var, syntax: "<integer>", value: to_string(value)}
  end

  def integer(value) do
    %{__type__: :typed_var, syntax: "<integer>", value: value}
  end

  @doc """
  Declares a CSS `<number>` type for a variable.

  For floating-point numbers without units.

  ## Examples

      number(0.5)
      number("1.5")
  """
  @spec number(number() | String.t() | map()) :: typed_value()
  def number(value) when is_number(value) do
    %{__type__: :typed_var, syntax: "<number>", value: to_string(value)}
  end

  def number(value) do
    %{__type__: :typed_var, syntax: "<number>", value: value}
  end

  @doc """
  Checks if a value is a typed variable.
  """
  @spec typed?(any()) :: boolean()
  def typed?(%{__type__: :typed_var}), do: true
  def typed?(_), do: false

  @doc """
  Extracts the initial value from a typed variable for use in @property.
  For conditional values (maps with :default), returns the default.
  """
  @spec initial_value(typed_value()) :: String.t()
  def initial_value(%{value: %{default: default}}) when is_binary(default), do: default
  def initial_value(%{value: value}) when is_binary(value), do: value
  def initial_value(%{value: value}) when is_integer(value), do: to_string(value)
  def initial_value(%{value: value}) when is_float(value), do: to_string(value)

  def initial_value(%{value: %{} = map}) do
    # For maps without :default key, try to find a sensible default
    case Map.get(map, :default) do
      nil ->
        # Use the first value as fallback
        map |> Map.values() |> List.first() |> to_string()

      val ->
        to_string(val)
    end
  end

  @doc """
  Extracts the actual CSS value(s) from a typed variable.
  Returns the value without the type wrapper.
  """
  @spec unwrap_value(typed_value()) :: String.t() | map()
  def unwrap_value(%{value: value}), do: value

  @doc """
  Creates a typed variable with a custom syntax.

  This is the low-level function used by `css_prop/3` macro.

  ## Examples

      typed_var(:color, "blue")
      typed_var(:angle, "0deg")
      typed_var("<color>#", "red, blue, green")  # Advanced syntax
      typed_var(:length, "1rem", true)  # inherits: true

  ## Syntax

  - Atoms like `:color`, `:angle`, `:length` are converted to CSS syntax strings
  - Strings are used as-is for advanced CSS syntax like `"<color>#"`
  """
  @spec typed_var(atom() | String.t(), String.t() | map(), boolean()) :: typed_value()
  def typed_var(syntax, value, inherits \\ false)

  def typed_var(syntax, value, inherits) when is_atom(syntax) do
    css_syntax = atom_to_syntax(syntax)
    %{__type__: :typed_var, syntax: css_syntax, value: value, inherits: inherits}
  end

  def typed_var(syntax, value, inherits) when is_binary(syntax) do
    %{__type__: :typed_var, syntax: syntax, value: value, inherits: inherits}
  end

  # Generate atom_to_syntax clauses from type definitions
  for {name, syntax, _doc} <- @simple_types do
    defp atom_to_syntax(unquote(name)), do: unquote(syntax)
  end

  defp atom_to_syntax(:integer), do: "<integer>"
  defp atom_to_syntax(:number), do: "<number>"
  defp atom_to_syntax(other), do: "<#{other}>"
end
