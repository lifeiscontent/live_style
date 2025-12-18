defmodule LiveStyle.Sheet do
  @moduledoc """
  Defines style rules for components.

  This is the primary module for defining styles in components.
  Use `LiveStyle.Tokens` separately for design tokens (CSS variables, keyframes, themes).

  ## Usage

      defmodule MyApp.Button do
        use Phoenix.Component
        use LiveStyle.Sheet

        css_rule :base,
          display: "inline-flex",
          padding: "0.5rem 1rem",
          border_radius: "0.25rem"

        css_rule :primary,
          background_color: css_var({MyApp.Tokens, :color, :primary}),
          color: css_var({MyApp.Tokens, :color, :white})

        def button(assigns) do
          ~H\"\"\"
          <button class={css_class([:base, :primary])}>
            <%= @label %>
          </button>
          \"\"\"
        end
      end

  ## Generated Functions

  Using `LiveStyle.Sheet` generates private `css/1` and `css_class/1` functions:

  - `css_class(refs)` - Returns a class string for use with `class={...}`
  - `css(refs)` - Returns `%LiveStyle.Attrs{}` for spreading with `{...}`

  ## Dynamic Rules

      css_rule :sized, fn size ->
        [
          padding: size,
          font_size: size
        ]
      end

      # Usage: css_class([{:sized, "1rem"}])

  ## Contextual Selectors

  Use `alias LiveStyle.When` for creating selectors that respond
  to ancestor/sibling state:

      alias LiveStyle.When

      css_rule :card,
        opacity: "1",
        When.ancestor(":hover") => [opacity: "0.8"]

  ## Cross-Module References

  Reference tokens from other modules:

      css_rule :animated,
        animation: "\#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"
  """

  defmacro __using__(_opts) do
    quote do
      import LiveStyle,
        only: [
          # Style definitions
          css_rule: 2,
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
          # Utilities
          first_that_works: 1
        ]

      # Accumulate rule definitions for @before_compile
      Module.register_attribute(__MODULE__, :__live_style_rules__, accumulate: true)

      @before_compile LiveStyle
    end
  end
end
