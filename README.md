# LiveStyle

Atomic CSS-in-Elixir for Phoenix LiveView, inspired by [Meta's StyleX](https://stylexjs.com/).

LiveStyle provides a type-safe, composable styling system with:

- **Atomic CSS**: Each property-value pair becomes a single class
- **Deterministic hashing**: Same styles always produce same class names
- **CSS Variables**: Type-safe design tokens with `defvars/2`
- **Theming**: Override variables with `create_theme/3`
- **@layer support**: CSS cascade layers for predictable specificity
- **Last-wins merging**: Like StyleX, later styles override earlier ones

## Installation

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.1.0"}
  ]
end
```

Add the LiveStyle compiler to your project:

```elixir
def project do
  [
    # ...
    compilers: Mix.compilers() ++ [:live_style]
  ]
end
```

Include the generated CSS in your root layout:

```heex
<link rel="stylesheet" href={~p"/assets/live.css"} />
```

## Configuration

Configure LiveStyle in your `config/config.exs`:

```elixir
config :live_style,
  output_path: "priv/static/assets/live.css",
  manifest_path: "_build/live_style_manifest.etf"
```

### Options

- `:output_path` - Path where the generated CSS file is written (default: `"priv/static/assets/live.css"`)
- `:manifest_path` - Path where the compile-time manifest is stored (default: `"_build/live_style_manifest.etf"`). Useful for monorepos or custom build directories.

## Quick Start

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle

  # Define styles using the macro
  style :base, %{
    display: "flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px"
  }

  style :primary, %{
    background_color: var(:fill_primary),
    color: "white"
  }

  def button(assigns) do
    ~H"""
    <button class={style([:base, :primary])}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
```

## Design Tokens

Define CSS custom properties for your design system:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  defvars :color, %{
    white: "#ffffff",
    black: "#000000",
    primary: "#1e68fa"
  }

  defvars :fill, %{
    primary: "#3b82f6",
    secondary: "#6b7280"
  }

  defvars :space, %{
    sm: "8px",
    md: "16px",
    lg: "24px"
  }
end
```

Use tokens in your styles with the `var/1` macro:

```elixir
style :container, %{
  padding: var(:space_md),
  background_color: var(:fill_primary)
}
```

## Theming

Create theme overrides that scope to an element and its children:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  defvars :fill, %{
    background: "#ffffff",
    surface: "#f5f5f5"
  }

  create_theme :dark, :fill, %{
    background: "#1a1a1a",
    surface: "#2d2d2d"
  }
end
```

Apply theme in templates:

```heex
<div class={MyApp.Tokens.dark()}>
  <!-- Children use dark theme colors -->
  <.button>I use dark colors</.button>
</div>
```

## Conditional Styles

Use Elixir's boolean logic for conditional styles:

```elixir
def button(assigns) do
  ~H"""
  <button class={style([:base, @variant == :primary && :primary, @disabled && :disabled])}>
    {render_slot(@inner_block)}
  </button>
  """
end
```

## Pseudo-classes and Media Queries

LiveStyle uses the StyleX pattern of condition-in-value:

```elixir
style :link, %{
  color: %{
    default: "blue",
    ":hover": "darkblue",
    ":focus": "navy"
  },
  text_decoration: "none"
}

style :container, %{
  padding: %{
    default: "16px",
    "@media (min-width: 768px)": "32px"
  }
}
```

## Pseudo-elements

```elixir
style :with_before, %{
  position: "relative",
  "::before": %{
    content: "'*'",
    color: "red",
    position: "absolute",
    left: "-1em"
  }
}
```

## Style Composition

Include styles from other modules or self-reference within the same module:

```elixir
# External module include
defmodule MyApp.BaseStyles do
  use LiveStyle

  style :button_base, %{
    display: "inline-flex",
    padding: "8px 16px",
    cursor: "pointer"
  }
end

defmodule MyApp.Button do
  use LiveStyle

  style :primary, %{
    __include__: [{MyApp.BaseStyles, :button_base}],
    background_color: var(:fill_primary)
  }
end

# Self-reference (same module)
defmodule MyApp.Card do
  use LiveStyle

  style :base, %{
    border_radius: "8px",
    padding: "16px"
  }

  style :elevated, %{
    __include__: [:base],
    box_shadow: "0 4px 6px rgba(0,0,0,0.1)"
  }
end
```

## Keyframes Animations

```elixir
defmodule MyApp.Animations do
  use LiveStyle

  keyframes :spin, %{
    from: %{transform: "rotate(0deg)"},
    to: %{transform: "rotate(360deg)"}
  }

  style :spinner, %{
    animation_name: :spin,
    animation_duration: "1s",
    animation_iteration_count: "infinite"
  }
end
```

## Fallback Values

Use `first_that_works/1` for CSS fallbacks:

```elixir
style :sticky_header, %{
  position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
}
```

## Typed Variables

For advanced use cases like animating gradients:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  import LiveStyle.Types

  defvars :anim, %{
    rotation: angle("0deg"),
    progress: percentage("0%")
  }

  defvars :theme, %{
    accent: color("#ff0000")
  }
end
```

This generates CSS `@property` rules that enable CSS to interpolate values.

## CSS Generation

CSS is automatically generated when you compile with the LiveStyle compiler.
You can also generate manually:

```bash
mix live_style.gen.css
```

Or specify a custom output path:

```bash
mix live_style.gen.css -o assets/css/live_style.css
```

## Development Watcher

For development, add the watcher to your Phoenix endpoint:

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    live_style: {LiveStyle.Watcher, :watch, [[]]}
  ]
```

The watcher monitors the LiveStyle manifest file and regenerates CSS whenever styles are recompiled. This requires the `file_system` dependency (included with `phoenix_live_reload`).

## Generated CSS Structure

```css
@property --v1234567 {
  syntax: '<color>';
  inherits: true;
  initial-value: #ff0000;
}

:root {
  --v1234567: #ff0000;
  --v2345678: 16px;
}

@keyframes k1234567 {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

@layer live_style {
  .x1a2b3c4 { display: flex; }
  .x2b3c4d5 { padding: var(--v2345678); }
  .x3c4d5e6 { background-color: var(--v1234567); }
}
```

## API Reference

### Core Macros (via `use LiveStyle`)

| Macro | Description |
|-------|-------------|
| `style/2` | Define a named style with CSS declarations |
| `keyframes/2` | Define a keyframes animation |
| `var/1` | Reference a CSS custom property |
| `first_that_works/1` | Declare fallback values for a property |

### Token Macros (via `use LiveStyle.Tokens`)

| Macro | Description |
|-------|-------------|
| `defvars/2` | Define CSS custom properties with a namespace |
| `defconsts/2` | Define compile-time constants (not CSS variables) |
| `defkeyframes/2` | Define keyframes in token modules |
| `create_theme/3` | Create theme overrides for a var group |

### Type Helpers (via `import LiveStyle.Types`)

| Function | Description |
|----------|-------------|
| `color/1` | CSS `<color>` type |
| `length/1` | CSS `<length>` type |
| `angle/1` | CSS `<angle>` type |
| `integer/1` | CSS `<integer>` type |
| `number/1` | CSS `<number>` type |
| `time/1` | CSS `<time>` type |
| `percentage/1` | CSS `<percentage>` type |

### Module Functions

| Function | Description |
|----------|-------------|
| `LiveStyle.get_all_css/0` | Get complete CSS output |
| `LiveStyle.clear/0` | Clear all collected CSS (useful for testing) |
| `LiveStyle.output_path/0` | Get configured CSS output path |
| `LiveStyle.manifest_path/0` | Get configured manifest path |

## Why LiveStyle?

### vs Tailwind CSS

- **Type-safe tokens**: Design tokens are Elixir values, not magic strings
- **No purging complexity**: Only styles you use are generated
- **Elixir-native**: Conditional logic uses `&&` and `||`, not string concatenation
- **Scoped theming**: Override tokens for subtrees without global CSS

### vs Inline Styles

- **Pseudo-classes**: `:hover`, `:focus`, etc. work naturally
- **Media queries**: Responsive design without JavaScript
- **Performance**: Atomic classes are cached and deduplicated
- **DevTools**: Inspect class names instead of inline style blobs

### Inspired by StyleX

LiveStyle brings Meta's StyleX philosophy to Phoenix LiveView:

- Atomic CSS for minimal bundle size
- Last-wins merging for predictable composition
- Deterministic class names for caching
- CSS variables for theming

## License

MIT License - see [LICENSE](LICENSE) for details.
