defmodule LiveStyle.Tokens do
  @moduledoc """
  Defines design tokens (CSS variables, keyframes, themes, view transitions).

  Use this module for centralized token modules that are shared across your app.
  Use `LiveStyle.Sheet` for component styles.

  ## Basic Usage

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_vars :space,
          sm: "0.5rem",
          md: "1rem",
          lg: "2rem"

        css_keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]
      end

  ## Theming Pattern

  The recommended pattern for theming uses two layers:

  1. **`:colors`** - Raw color palette (hex values, not themed)
  2. **`:semantic`** - Semantic tokens that reference colors via `css_var` (themed)

  This separation allows themes to swap which raw colors semantic tokens point to,
  without duplicating color values.

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Raw color palette (not themed)
        css_vars :colors,
          white: "#ffffff",
          black: "#000000",
          gray_50: "#f9fafb",
          gray_900: "#111827",
          indigo_500: "#6366f1",
          indigo_400: "#818cf8"

        # Semantic tokens reference colors (themed)
        css_vars :semantic,
          text_primary: css_var({:colors, :gray_900}),
          text_inverse: css_var({:colors, :white}),
          fill_primary: css_var({:colors, :indigo_500}),
          fill_page: css_var({:colors, :white})

        # Dark theme overrides semantic tokens to point to different colors
        css_theme :semantic, :dark,
          text_primary: css_var({:colors, :gray_50}),
          text_inverse: css_var({:colors, :gray_900}),
          fill_primary: css_var({:colors, :indigo_400}),
          fill_page: css_var({:colors, :gray_900})
      end

  ### Why This Pattern?

  - **Single source of truth**: Colors are defined once in `:colors`
  - **Semantic naming**: Components use meaningful names like `text_primary`
  - **Easy theming**: Switch themes by remapping semantic → color references
  - **No duplication**: Raw hex values aren't repeated across themes

  ### Applying Themes

  Use `css_theme/1` in templates to apply a theme to a subtree:

      # In your root layout or component
      <div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
        <!-- All children use dark theme colors -->
      </div>

  Components don't need to know about themes - they just reference semantic tokens:

      css_class :button,
        color: css_var({MyApp.Tokens, :semantic, :text_inverse}),
        background: css_var({MyApp.Tokens, :semantic, :fill_primary})

  ## Typed Variables

  For animatable properties like gradients, declare types with `LiveStyle.Types`:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens
        import LiveStyle.Types

        css_vars :anim,
          angle: angle("0deg"),
          hue: percentage("0%")
      end

  This generates CSS `@property` rules that enable CSS to interpolate values.
  See `LiveStyle.Types` for all available type helpers.

  ## Compile-Time Constants

  For values that should be inlined at compile-time (not CSS variables), use `css_consts/2`:

      css_consts :breakpoint,
        sm: "@media (max-width: 640px)",
        lg: "@media (min-width: 1025px)"

      css_consts :z,
        modal: "50",
        tooltip: "100"

  Reference constants with `css_const/1`:

      css_class :modal,
        z_index: css_const({MyApp.Tokens, :z, :modal})

  ## Referencing Tokens

  In components using `LiveStyle.Sheet`:

      defmodule MyApp.Button do
        use LiveStyle.Sheet

        css_class :base,
          background_color: css_var({MyApp.Tokens, :semantic, :fill_primary}),
          animation: "\#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"
      end

  ## Available Macros

  ### Definition Macros

  - `css_vars/2` - Define CSS custom properties with a namespace
  - `css_consts/2` - Define compile-time constants (inlined, not CSS variables)
  - `css_keyframes/2` - Define `@keyframes` animation
  - `css_theme/3` - Create theme overrides for a variable namespace
  - `css_position_try/2` - Define `@position-try` rules for CSS Anchor Positioning
  - `css_view_transition/2` - Define view transition styles

  ### Reference Macros

  - `css_var/1` - Reference a CSS variable
  - `css_const/1` - Reference a compile-time constant
  - `css_keyframes/1` - Reference keyframes
  - `css_theme/1` - Reference a theme (returns class name)
  - `css_position_try/1` - Reference position-try
  - `css_view_transition/1` - Reference view transition
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
