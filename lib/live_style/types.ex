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
          accent: color(%{:default => "blue", "@media (prefers-color-scheme: dark)" => "lightblue"})

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

      css_class :gradient,
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

  alias LiveStyle.Types.Helpers
  alias LiveStyle.Types.Numeric
  alias LiveStyle.Types.Simple
  alias LiveStyle.Types.TypedVar

  # Keep the public API stable; implementations live in submodules.

  def color(value), do: Simple.color(value)
  def length(value), do: Simple.length(value)
  def angle(value), do: Simple.angle(value)
  def time(value), do: Simple.time(value)
  def percentage(value), do: Simple.percentage(value)
  def url(value), do: Simple.url(value)
  def image(value), do: Simple.image(value)
  def resolution(value), do: Simple.resolution(value)
  def length_percentage(value), do: Simple.length_percentage(value)
  def transform_function(value), do: Simple.transform_function(value)
  def transform_list(value), do: Simple.transform_list(value)

  def integer(value), do: Numeric.integer(value)
  def number(value), do: Numeric.number(value)

  def typed?(value), do: Helpers.typed?(value)
  def initial_value(value), do: Helpers.initial_value(value)
  def unwrap_value(value), do: Helpers.unwrap_value(value)

  def typed_var(syntax, value, opts \\ []), do: TypedVar.typed_var(syntax, value, opts)
end
