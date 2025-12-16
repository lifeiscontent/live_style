defmodule LiveStyle.Tokens do
  @moduledoc """
  Provides macros for defining design tokens (CSS custom properties).

  ## Usage

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        defvars :color, %{
          white: "#ffffff",
          black: "#000000",
          blue_500: "#1e68fa"
        }

        defvars :fill, %{
          primary: "var(--v...)",  # Can reference other vars
          danger: "#d62931"
        }

        defvars :radius, %{
          sm: "0.125rem",
          lg: "0.5rem"
        }

        defkeyframes :spin, %{
          from: %{transform: "rotate(0deg)"},
          to: %{transform: "rotate(360deg)"}
        }
      end

  ## Typed Variables

  For advanced use cases like animating gradients, you can declare types:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens
        import LiveStyle.Types

        defvars :anim, %{
          angle: angle("0deg"),
          color: color("blue")
        }
      end

  This generates CSS `@property` rules that enable CSS to interpolate values.

  Then in your components:

      defmodule MyApp.Button do
        use LiveStyle

        style :base, %{
          background_color: var(:fill_primary),
          border_radius: var(:radius_lg)
        }
      end

  The `var(:fill_primary)` macro generates a deterministic hashed CSS variable
  reference like `var(--v1a2b3c4)` at compile time.
  """

  defmacro __using__(_opts) do
    quote do
      import LiveStyle, only: [defvars: 2, defconsts: 2, defkeyframes: 2, create_theme: 3, var: 1]

      # Register attribute for compile-time keyframe lookups (used by ViewTransitions)
      Module.register_attribute(__MODULE__, :__live_keyframes_map__, accumulate: true)
    end
  end
end
