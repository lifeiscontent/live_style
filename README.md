# LiveStyle

Atomic CSS-in-Elixir for Phoenix LiveView, inspired by [Meta's StyleX](https://stylexjs.com/).

LiveStyle provides a type-safe, composable styling system with:

- **Atomic CSS**: Each property-value pair becomes a single class
- **Deterministic hashing**: Same styles always produce same class names
- **CSS Variables**: Type-safe design tokens with `vars/1`
- **Constants**: Static values inlined at compile time with `consts/1`
- **Theming**: Override variables with `theme/2`
- **@layer support**: CSS cascade layers for predictable specificity
- **Last-wins merging**: Like StyleX, later styles override earlier ones

## Installation

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.11.0"}
  ]
end
```

See the [Getting Started](guides/getting-started.md) guide for complete setup instructions.

## Quick Example

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle

  class :base,
    display: "inline-flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "6px"

  class :primary,
    background_color: "#4f46e5",
    color: "white",
    ":hover": [background_color: "#4338ca"]

  def button(assigns) do
    ~H"""
    <button {css([:base, :primary])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

## Guides

- [Getting Started](guides/getting-started.md) - Installation and setup
- [Design Tokens](guides/design-tokens.md) - CSS variables, constants, and keyframes
- [Styling Components](guides/styling-components.md) - Defining and composing styles
- [Theming](guides/theming.md) - Creating and applying themes
- [Advanced Features](guides/advanced-features.md) - Contextual selectors, view transitions, anchor positioning
- [Configuration](guides/configuration.md) - Shorthand behaviors and options

## Key Concepts

### Design Tokens

Use `vars` for values that change (colors, themed tokens) and `consts` for static values:

```elixir
defmodule MyAppWeb.Colors do
  use LiveStyle

  vars primary: "#4f46e5",
       gray_900: "#111827"
end

defmodule MyAppWeb.Spacing do
  use LiveStyle

  consts sm: "8px",
         md: "16px"
end

defmodule MyAppWeb.Animations do
  use LiveStyle

  keyframes :fade_in,
    from: [opacity: "0"],
    to: [opacity: "1"]
end
```

### Component Styles

Reference tokens with `var` for colors and `const` for static values:

```elixir
defmodule MyAppWeb.Card do
  use LiveStyle

  class :card,
    padding: const({MyAppWeb.Spacing, :md}),
    border_radius: "12px",
    color: var({MyAppWeb.Colors, :gray_900})
end
```

### Theming

Create theme variations (only works with `vars`):

```elixir
defmodule MyAppWeb.Semantic do
  use LiveStyle

  vars text_primary: var({MyAppWeb.Colors, :gray_900}),
       fill_page: "#ffffff"

  theme :dark,
    text_primary: "#ffffff",
    fill_page: var({MyAppWeb.Colors, :gray_900})
end

# In your template
<html {css(@theme == :dark && theme({MyAppWeb.Semantic, :dark}))}>
```

### Pseudo-classes & Media Queries

```elixir
class :link,
  color: [
    default: "blue",
    ":hover": "darkblue"
  ]

class :container,
  padding: [
    default: const({MyAppWeb.Spacing, :md}),
    "@media (min-width: 768px)": "24px"
  ]
```

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

## Optional Integrations

```elixir
def deps do
  [
    {:live_style, "~> 0.11.0"},
    # Automatic vendor prefixing
    {:autoprefixer_ex, "~> 0.1.0"},
    # Deprecation warnings for CSS properties
    {:css_compat_data_ex, "~> 0.1.0"}
  ]
end
```

## License

MIT License - see [LICENSE](LICENSE) for details.
