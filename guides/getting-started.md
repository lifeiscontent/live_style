# Getting Started

This guide walks you through setting up LiveStyle in a Phoenix application.

## Installation

### 1. Add Dependencies

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.10.0"},
    # Optional: for automatic vendor prefixing
    {:autoprefixer_ex, "~> 0.1.0"},
    # Optional: for deprecation warnings
    {:css_compat_data_ex, "~> 0.1.0"}
  ]
end
```

### 2. Add the LiveStyle Compiler

In `mix.exs`, add `:live_style` to your compilers:

```elixir
def project do
  [
    # ...
    compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:live_style]
  ]
end
```

### 3. Configure LiveStyle

Add to `config/config.exs`:

```elixir
# Configure LiveStyle
config :live_style,
  # Optional: automatic vendor prefixing
  prefix_css: &AutoprefixerEx.prefix_css/2,
  # Optional: deprecation warnings
  deprecated?: &CSSCompatDataEx.deprecated?/1,
  default: [
    output: "priv/static/assets/live.css",
    cd: Path.expand("..", __DIR__)
  ]

# Optional: configure browser targets for autoprefixing
config :autoprefixer_ex,
  browserslist: ["defaults"]
```

### 4. Add Development Watcher

Add to `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    # ... other watchers
    live_style: {LiveStyle.Compiler, :run, [:default, ~w(--watch)]}
  ]
```

### 5. Update Build Aliases

In `mix.exs`, update your aliases:

```elixir
defp aliases do
  [
    setup: ["deps.get", "assets.setup", "assets.build"],
    "assets.setup": ["esbuild.install --if-missing"],
    "assets.build": ["compile", "esbuild my_app", "live_style default"],
    "assets.deploy": [
      "live_style default",
      "esbuild my_app --minify",
      "phx.digest"
    ]
  ]
end
```

### 6. Include CSS in Layout

Add the LiveStyle CSS to your root layout (`lib/my_app_web/components/layouts/root.html.heex`):

```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/live.css"} />
```

### 7. Add CSS Reset (Optional but Recommended)

Create a base CSS reset in `assets/css/app.css`:

```css
/*
 * CSS Reset and base styles.
 * Wrapped in @layer reset so LiveStyle rules take precedence.
 */

@layer reset {
  *,
  *::before,
  *::after {
    box-sizing: border-box;
  }

  * {
    margin: 0;
    padding: 0;
  }

  body {
    min-height: 100vh;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
  }

  img, picture, video, canvas, svg {
    display: block;
    max-width: 100%;
  }

  input, button, textarea, select {
    font: inherit;
  }

  /* Phoenix LiveView compatibility */
  [data-phx-main],
  [data-phx-session] {
    display: contents;
  }
}
```

### 8. Test Setup (If Needed)

If your tests define LiveStyle modules (e.g., test fixtures with `use LiveStyle.Sheet`),
add the test setup task to your aliases:

```elixir
defp aliases do
  [
    # ...
    test: ["live_style.setup_tests", "test"]
  ]
end
```

## Quick Start

Here's a complete example of a styled button component:

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  # Define styles using keyword list syntax
  css_class :base,
    display: "flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px",
    border: "none",
    cursor: "pointer"

  css_class :primary,
    background_color: "#4f46e5",
    color: "white"

  css_class :secondary,
    background_color: "#e5e7eb",
    color: "#1f2937"

  def button(assigns) do
    assigns = assign_new(assigns, :variant, fn -> :primary end)

    ~H"""
    <button class={css_class([:base, @variant])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

Use it in your templates:

```heex
<.button>Primary Button</.button>
<.button variant={:secondary}>Secondary Button</.button>
```

## Module Organization

LiveStyle provides two specialized modules for clearer intent:

### `LiveStyle.Tokens` - Design Tokens

For centralized design tokens. Use `css_vars` for values that change (colors, themed tokens) and `css_consts` for static values:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Colors use css_vars (needed for theming)
  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    indigo_600: "#4f46e5"

  # Static values use css_consts (no CSS variable overhead)
  css_consts :space,
    sm: "8px",
    md: "16px",
    lg: "24px"

  css_consts :radius,
    sm: "4px",
    md: "8px",
    lg: "12px"

  css_keyframes :spin,
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
end
```

### `LiveStyle.Sheet` - Component Styles

For component-specific styles. Use `css_var` for colors/themed values, `css_const` for static values:

```elixir
defmodule MyApp.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  css_class :base,
    display: "inline-flex",
    padding: css_const({MyApp.Tokens, :space, :md}),
    border_radius: css_const({MyApp.Tokens, :radius, :md})

  css_class :primary,
    background_color: css_var({MyApp.Tokens, :colors, :indigo_600}),
    color: css_var({MyApp.Tokens, :colors, :white})

  def button(assigns) do
    ~H"""
    <button class={css_class([:base, :primary])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

## Next Steps

- [Design Tokens](design-tokens.md) - Learn about CSS variables, constants, and keyframes
- [Styling Components](styling-components.md) - Deep dive into `css_class` and composition
- [Theming](theming.md) - Create and apply themes
- [Configuration](configuration.md) - Configure shorthand behaviors and other options
