defmodule LiveStyle.Sheet do
  @moduledoc """
  Defines style classes for components.

  This is the primary module for defining styles in Phoenix components.
  Use `LiveStyle.Tokens` separately for design tokens (CSS variables, keyframes, themes).

  ## Usage

      defmodule MyApp.Button do
        use Phoenix.Component
        use LiveStyle.Sheet

        css_class :base,
          display: "inline-flex",
          padding: "0.5rem 1rem",
          border_radius: "0.25rem"

        css_class :primary,
          background_color: css_var({MyApp.Tokens, :color, :primary}),
          color: css_var({MyApp.Tokens, :color, :white})

        def button(assigns) do
          ~H\"\"\"
          <button class={css_class([:base, :primary])}>
            <%= render_slot(@inner_block) %>
          </button>
          \"\"\"
        end
      end

  ## Generated Functions

  Using `LiveStyle.Sheet` generates private `css/1` and `css_class/1` functions:

  - `css_class(refs)` - Returns a class string for use with `class={...}`
  - `css(refs)` - Returns `%LiveStyle.Attrs{}` for spreading with `{...}`

  The `refs` parameter can be:
  - A single atom: `css_class(:base)`
  - A list of atoms: `css_class([:base, :primary])`
  - A list with conditionals: `css_class([:base, @variant == :primary && :primary])`
  - Dynamic classes: `css_class([{:sized, "1rem"}])`

  ## Dynamic Classes

  Dynamic classes use a function to generate styles at runtime with CSS variables:

      css_class :sized, fn size ->
        [
          padding: size,
          font_size: size
        ]
      end

      # Usage in template:
      <div {css([{:sized, "1rem"}])}>Content</div>

  Multiple parameters are passed as a list:

      css_class :positioned, fn x, y ->
        [left: x, top: y]
      end

      # Usage:
      <div {css([{:positioned, ["10px", "20px"]}])}>Content</div>

  ## Pseudo-classes and Media Queries

  Use the condition-in-value pattern for pseudo-classes and media queries:

      css_class :link,
        color: %{
          :default => "blue",
          ":hover" => "darkblue",
          ":focus" => "navy"
        }

      css_class :responsive,
        padding: %{
          :default => "16px",
          "@media (min-width: 768px)" => "32px"
        }

  ## Pseudo-elements

      css_class :with_before,
        position: "relative",
        "::before": [
          content: "'*'",
          color: "red"
        ]

  ## Contextual Selectors

  Use `alias LiveStyle.When` for creating selectors that respond
  to ancestor/sibling state. Note: computed keys require map syntax with `=>`:

      alias LiveStyle.When

      css_class :card,
        opacity: %{
          :default => "1",
          When.ancestor(":hover") => "0.8"
        }

  See `LiveStyle.When` for all available contextual selectors.

  ## Style Composition

  Include styles from other classes with `__include__`:

      css_class :base,
        display: "flex",
        padding: "8px"

      css_class :elevated,
        __include__: [:base],
        box_shadow: "0 4px 6px rgba(0,0,0,0.1)"

  Cross-module includes are also supported:

      css_class :themed_button,
        __include__: [{MyApp.BaseStyles, :btn_base}],
        color: css_var({MyApp.Tokens, :semantic, :text_primary})

  See `LiveStyle.Include` for details.

  ## Cross-Module References

  Reference tokens from other modules:

      css_class :animated,
        animation: "\#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"

  ## Available Macros

  - `css_class/2` - Define a static or dynamic style class
  - `css_keyframes/2` - Define keyframes (typically done in Tokens module)
  - `css_position_try/2` - Define position-try rules
  - `css_view_transition/2` - Define view transitions
  - `css_var/1` - Reference CSS variables
  - `css_const/1` - Reference compile-time constants
  - `css_keyframes/1` - Reference keyframes
  - `css_theme/1` - Reference themes
  - `css_position_try/1` - Reference position-try rules
  - `css_view_transition/1` - Reference view transitions
  - `first_that_works/1` - Define fallback values
  """

  defmacro __using__(_opts) do
    quote do
      import LiveStyle,
        only: [
          # Style definitions
          css_class: 2,
          css_keyframes: 2,
          css_position_try: 2,
          css_view_transition: 2,
          # Reference macros (for cross-module token references)
          css_var: 1,
          css_const: 1,
          css_keyframes: 1,
          css_position_try: 1,
          css_view_transition: 1,
          css_theme: 1,
          # Runtime resolution macros
          css_class: 1,
          css: 1,
          css: 2,
          # Utilities
          first_that_works: 1
        ]

      # Accumulate class definitions for @before_compile
      Module.register_attribute(__MODULE__, :__live_style_classes__, accumulate: true)

      @before_compile LiveStyle
    end
  end
end
