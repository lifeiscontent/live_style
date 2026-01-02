# Getting Started

This guide walks you through setting up LiveStyle in a Phoenix application.

## Installation

### 1. Add Dependencies

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.11.0"},
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

### 3. Configure Esbuild for CSS

Phoenix uses esbuild for JavaScript. Add a separate profile for CSS bundling in `config/config.exs`:

```elixir
config :esbuild,
  version: "0.25.4",
  my_app: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  css: [
    args: ~w(css/app.css --bundle --outdir=../priv/static/assets/css),
    cd: Path.expand("../assets", __DIR__)
  ]
```

### 4. Configure LiveStyle

Add to `config/config.exs`:

```elixir
# Configure LiveStyle
config :live_style,
  # Optional: automatic vendor prefixing
  prefix_css: &AutoprefixerEx.prefix_css/2,
  # Optional: deprecation warnings
  deprecated?: &CSSCompatDataEx.deprecated?/1,
  default: [
    output: "priv/static/assets/css/live.css",
    cd: Path.expand("..", __DIR__)
  ]

# Optional: configure browser targets for autoprefixing
config :autoprefixer_ex,
  browserslist: ["defaults"]
```

### 5. Add Development Watchers

Add to `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    esbuild_css: {Esbuild, :install_and_run, [:css, ~w(--watch)]},
    live_style: {LiveStyle.Compiler.Runner, :run, [:default, ~w(--watch)]}
  ]
```

### 6. Update Build Aliases

In `mix.exs`, update your aliases:

```elixir
defp aliases do
  [
    setup: ["deps.get", "assets.setup", "assets.build"],
    "assets.setup": ["esbuild.install --if-missing"],
    "assets.build": ["compile", "esbuild my_app", "esbuild css", "live_style default"],
    "assets.deploy": [
      "live_style default",
      "esbuild my_app --minify",
      "esbuild css --minify",
      "phx.digest"
    ]
  ]
end
```

### 7. Include CSS in Layout

Add the stylesheets to your root layout (`lib/my_app_web/components/layouts/root.html.heex`):

```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/live.css"} />
<script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}></script>
```

### 8. Add CSS Reset (Optional but Recommended)

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

### 9. Test Setup (If Needed)

If your tests define LiveStyle modules (e.g., test fixtures with `use LiveStyle`),
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
  use LiveStyle

  class :base,
    display: "flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px",
    border: "none",
    cursor: "pointer"

  class :primary,
    background_color: "#4f46e5",
    color: "white"

  class :secondary,
    background_color: "#e5e7eb",
    color: "#1f2937"

  def button(assigns) do
    assigns = assign_new(assigns, :variant, fn -> :primary end)

    ~H"""
    <button {css([:base, @variant])}>
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

LiveStyle uses a module-as-namespace pattern. Each module defines its own tokens or styles.

### Design Tokens

For centralized design tokens, create separate modules for each token type. Use `vars` for values that might be themed (colors) and `consts` for static values:

```elixir
defmodule MyAppWeb.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    indigo_600: "#4f46e5"
  ]
end

defmodule MyAppWeb.Spacing do
  use LiveStyle

  consts [
    sm: "8px",
    md: "16px",
    lg: "24px"
  ]
end

defmodule MyAppWeb.Radius do
  use LiveStyle

  consts [
    sm: "4px",
    md: "8px",
    lg: "12px"
  ]
end

defmodule MyAppWeb.Animations do
  use LiveStyle

  keyframes :spin,
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
end
```

### Component Styles

For component-specific styles, use `var` for colors/themed values and `const` for static values:

```elixir
defmodule MyAppWeb.Button do
  use Phoenix.Component
  use LiveStyle

  class :base,
    display: "inline-flex",
    padding: const({MyAppWeb.Spacing, :md}),
    border_radius: const({MyAppWeb.Radius, :md})

  class :primary,
    background_color: var({MyAppWeb.Colors, :indigo_600}),
    color: var({MyAppWeb.Colors, :white})

  def button(assigns) do
    ~H"""
    <button {css([:base, :primary])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

## Next Steps

- [Design Tokens](design-tokens.md) - Learn about CSS variables, constants, and keyframes
- [Styling Components](styling-components.md) - Deep dive into `class` and composition
- [Theming](theming.md) - Create and apply themes
- [Configuration](configuration.md) - Configure shorthand behaviors and other options
