defmodule LiveStyle.Tokens do
  @moduledoc """
  Defines design tokens (CSS variables, keyframes, themes).

  Use this for centralized token modules that are shared across your app.
  Use `LiveStyle.Sheet` for component styles.

  ## Usage

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_vars :color,
          white: "#ffffff",
          black: "#000000",
          primary: "#3b82f6"

        css_vars :space,
          sm: "0.5rem",
          lg: "2rem"

        css_keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]

        css_theme {:color, :dark},
          white: "#1f2937",
          black: "#f9fafb"
      end

  ## Typed Variables

  For animatable properties, declare types with `LiveStyle.Types`:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens
        import LiveStyle.Types

        css_vars :anim,
          angle: angle("0deg"),
          hue: percentage("0%")
      end

  This generates CSS `@property` rules that enable CSS to interpolate values.

  ## Referencing Tokens

  In components using `LiveStyle.Sheet`:

      defmodule MyApp.Button do
        use LiveStyle.Sheet

        css_rule :base,
          background_color: css_var({MyApp.Tokens, :color, :primary}),
          animation: "\#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"
      end
  """

  defmacro __using__(_opts) do
    quote do
      import LiveStyle,
        only: [
          # Definition macros
          css_vars: 2,
          css_consts: 2,
          css_keyframes: 2,
          css_position_try: 2,
          css_view_transition: 2,
          css_theme: 3,
          # Reference macros
          css_var: 1,
          css_const: 1,
          css_keyframes: 1,
          css_position_try: 1,
          css_view_transition: 1,
          css_theme: 1
        ]
    end
  end
end
