defmodule LiveStyle.Types do
  @moduledoc """
  Type helpers for CSS custom properties.

  These functions wrap variable values to declare their CSS type, enabling
  features like animating gradients or capturing computed values.

  When a typed variable is defined with `defvars`, LiveStyle generates a
  CSS `@property` rule that registers the variable's type with the browser.

  ## Example

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens
        import LiveStyle.Types

        defvars(:color, %{
          primary: color("black"),
          accent: color({default: "blue", "@media (prefers-color-scheme: dark)": "lightblue"})
        })

        defvars(:animation, %{
          angle: angle("0deg")
        })
      end

  This generates:

      @property --v1234567 {
        syntax: '<color>';
        inherits: true;
        initial-value: black;
      }

  ## Supported Types

  - `color/1` - CSS `<color>` values
  - `length/1` - CSS `<length>` values (px, rem, em, etc.)
  - `angle/1` - CSS `<angle>` values (deg, rad, turn, etc.)
  - `integer/1` - CSS `<integer>` values
  - `number/1` - CSS `<number>` values (floating point)
  - `time/1` - CSS `<time>` values (s, ms)
  - `percentage/1` - CSS `<percentage>` values

  ## Use Cases

  ### Animating Gradients

  Normally gradients cannot be animated. With typed angle variables, you can:

      defvars(:anim, %{
        angle: angle("0deg")
      })

      # In a component:
      keyframes :rotate, %{
        from: %{var(:anim_angle) => "0deg"},
        to: %{var(:anim_angle) => "360deg"}
      }

      style :gradient, %{
        background_image: "conic-gradient(from \#{var(:anim_angle)}, red, blue)",
        animation: "rotate 10s linear infinite"
      }

  ### Simulating round()

  Integer types discard fractional values:

      defvars(:layout, %{
        columns: integer(3)
      })

      # Math.floor: calc(16 / 9) -> 1
      # Math.round: calc((16 / 9) + 0.5) -> 2
  """

  @type typed_value :: %{
          __type__: atom(),
          syntax: String.t(),
          value: String.t() | map()
        }

  @doc """
  Declares a CSS `<color>` type for a variable.

  Enables color interpolation in animations and transitions.

  ## Examples

      color("black")
      color("#ff0000")
      color("rgb(255, 0, 0)")
      color({default: "black", "@media (prefers-color-scheme: dark)": "white"})
  """
  @spec color(String.t() | map()) :: typed_value()
  def color(value) do
    %{__type__: :typed_var, syntax: "<color>", value: value}
  end

  @doc """
  Declares a CSS `<length>` type for a variable.

  Enables length interpolation and capturing computed values like `1em`.

  ## Examples

      length("4px")
      length("1rem")
      length("1em")
      length({default: "8px", "@media (min-width: 768px)": "16px"})
  """
  @spec length(String.t() | map()) :: typed_value()
  def length(value) do
    %{__type__: :typed_var, syntax: "<length>", value: value}
  end

  @doc """
  Declares a CSS `<angle>` type for a variable.

  Enables angle interpolation - useful for animating gradients.

  ## Examples

      angle("0deg")
      angle("45deg")
      angle("0.5turn")
  """
  @spec angle(String.t() | map()) :: typed_value()
  def angle(value) do
    %{__type__: :typed_var, syntax: "<angle>", value: value}
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
  Declares a CSS `<time>` type for a variable.

  For duration values in animations and transitions.

  ## Examples

      time("0.5s")
      time("300ms")
  """
  @spec time(String.t() | map()) :: typed_value()
  def time(value) do
    %{__type__: :typed_var, syntax: "<time>", value: value}
  end

  @doc """
  Declares a CSS `<percentage>` type for a variable.

  ## Examples

      percentage("50%")
      percentage("100%")
  """
  @spec percentage(String.t() | map()) :: typed_value()
  def percentage(value) do
    %{__type__: :typed_var, syntax: "<percentage>", value: value}
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
end
