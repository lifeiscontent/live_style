# Getting Started

LiveStyle is a compile-time CSS-in-Elixir library for Phoenix.

## Migrating from Tailwind

It's a find-and-replace:

| Find | Replace |
|------|---------|
| `@import "tailwindcss"` | `@import "live_style"` |
| `{:tailwind, ...}` | `{:live_style, "~> 0.0"}` |
| `config :tailwind, my_app: [...]` | `config :live_style, my_app: [...]` |
| `tailwind my_app` | `live_style my_app` |
| `Tailwind` | `LiveStyle` |

Plus add the compiler to `mix.exs`:

```elixir
compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:live_style]
```

### Full Example

**`assets/css/app.css`** — replace the import:
```css
@import "live_style";
```

**`mix.exs`** — swap dep and add compiler:
```elixir
def project do
  [
    compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:live_style],
    ...
  ]
end

def deps do
  [
    {:live_style, "~> 0.0"},
    ...
  ]
end

defp aliases do
  [
    "assets.setup": ["esbuild.install --if-missing"],
    "assets.build": ["compile", "live_style my_app", "esbuild my_app"],
    "assets.deploy": ["live_style my_app", "esbuild my_app --minify", "phx.digest"],
    ...
  ]
end
```

**`config/config.exs`** — same pattern as Tailwind:
```elixir
config :live_style,
  my_app: [
    input: "assets/css/app.css",
    output: "priv/static/assets/css/app.css"
  ]
```

**`config/dev.exs`** — swap the watcher:
```elixir
watchers: [
  esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
  live_style: {LiveStyle, :install_and_run, [:my_app, ~w(--watch)]}
]
```

Run `mix deps.get` and you're done.

### Incremental Migration

Mix LiveStyle with existing CSS classes—strings pass through unchanged:

```heex
<div {css([:card, "existing-tailwind-class"])}>
  Content
</div>
```

---

## New Project Setup

For new Phoenix projects without Tailwind:

### 1. Add Dependency

```elixir
# mix.exs
def deps do
  [
    {:live_style, "~> 0.0"}
  ]
end
```

### 2. Add Compiler

```elixir
# mix.exs
def project do
  [
    # ...
    compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:live_style]
  ]
end
```

### 3. Configure LiveStyle

```elixir
# config/config.exs
config :live_style,
  my_app: [
    input: "assets/css/app.css",
    output: "priv/static/assets/css/app.css"
  ]
```

### 4. Add Import Directive

```css
/* assets/css/app.css */
@layer reset {
  *, *::before, *::after { box-sizing: border-box; }
  * { margin: 0; padding: 0; }
  body { line-height: 1.5; -webkit-font-smoothing: antialiased; }
  img, picture, video, canvas, svg { display: block; max-width: 100%; }
  input, button, textarea, select { font: inherit; }
}

@import "live_style";
```

### 5. Add Watcher

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    live_style: {LiveStyle, :install_and_run, [:my_app, ~w(--watch)]}
  ]
```

### 6. Update Aliases

```elixir
# mix.exs
defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
    "assets.setup": ["esbuild.install --if-missing"],
    "assets.build": ["compile", "live_style my_app", "esbuild my_app"],
    "assets.deploy": ["live_style my_app", "esbuild my_app --minify", "phx.digest"]
  ]
end
```

### 7. Single Stylesheet in Layout

```heex
<%!-- lib/my_app_web/components/layouts/root.html.heex --%>
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
```

---

## Quick Start: Your First Component

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle

  class :base,
    display: "inline-flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px",
    border: "none",
    cursor: "pointer",
    font_weight: "500"

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

Use in templates:

```heex
<.button>Primary</.button>
<.button variant={:secondary}>Secondary</.button>
```

---

## Project Structure

Organize styles in a dedicated directory:

```
lib/my_app_web/
├── style/
│   ├── tokens.ex      # Spacing, typography, borders
│   └── semantic.ex    # Themed colors (light/dark)
├── components/
│   └── core_components.ex
└── ...
```

### Design Tokens

```elixir
# lib/my_app_web/style/tokens.ex
defmodule MyAppWeb.Style.Tokens do
  use LiveStyle

  consts(
    spacing_1: "0.25rem",
    spacing_2: "0.5rem",
    spacing_4: "1rem",
    radius_md: "0.375rem"
  )
end
```

### Themed Colors

```elixir
# lib/my_app_web/style/semantic.ex
defmodule MyAppWeb.Style.Semantic do
  use LiveStyle

  # Light theme (default)
  vars(
    surface: "oklch(97% 0.008 25)",
    text: "oklch(25% 0.035 25)",
    primary: "oklch(45% 0.2 25)"
  )

  # Dark theme
  theme_class(:dark,
    surface: "oklch(15% 0.015 25)",
    text: "oklch(93% 0.008 25)",
    primary: "oklch(65% 0.18 25)"
  )
end
```

### Using Tokens

```elixir
defmodule MyAppWeb.CoreComponents do
  use Phoenix.Component
  use LiveStyle

  alias MyAppWeb.Style.{Semantic, Tokens}

  class :card,
    padding: const({Tokens, :spacing_4}),
    border_radius: const({Tokens, :radius_md}),
    background_color: var({Semantic, :surface}),
    color: var({Semantic, :text})
end
```

### Live Reload

Watch style modules in `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/my_app_web/(controllers|live|components)/.*\.(ex|heex)$",
      ~r"lib/my_app_web/style/.*\.ex$"
    ]
  ]
```

---

## Next Steps

- [Design Tokens](design-tokens.md) - CSS variables, constants, and keyframes
- [Styling Components](styling-components.md) - Deep dive into `class` and composition
- [Theming](theming.md) - Light/dark themes and user preferences
- [Configuration](configuration.md) - Shorthand behaviors, validation, and more
