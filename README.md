# LiveStyle

Atomic CSS-in-Elixir for Phoenix LiveView, inspired by [Meta's StyleX](https://stylexjs.com/).

LiveStyle provides a type-safe, composable styling system with:

- **Atomic CSS**: Each property-value pair becomes a single class
- **Deterministic hashing**: Same styles always produce same class names
- **CSS Variables**: Type-safe design tokens with `css_vars/2`
- **Constants**: Static values inlined at compile time with `css_consts/2`
- **Theming**: Override variables with `css_theme/3`
- **@layer support**: CSS cascade layers for predictable specificity
- **Last-wins merging**: Like StyleX, later styles override earlier ones

## Installation

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.8.1"}
  ]
end
```

See the [Getting Started](guides/getting-started.md) guide for complete setup instructions.

## Quick Example

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  css_class :base,
    display: "inline-flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "6px"

  css_class :primary,
    background_color: "#4f46e5",
    color: "white",
    ":hover": [background_color: "#4338ca"]

  def button(assigns) do
    ~H"""
    <button class={css_class([:base, :primary])}>
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

Use `css_vars` for values that change (colors, themed tokens) and `css_consts` for static values:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Colors use css_vars (for theming)
  css_vars :colors,
    primary: "#4f46e5",
    gray_900: "#111827"

  # Static values use css_consts
  css_consts :space,
    sm: "8px",
    md: "16px"

  css_consts :radius,
    md: "8px",
    lg: "12px"

  css_keyframes :fade_in,
    from: [opacity: "0"],
    to: [opacity: "1"]
end
```

### Component Styles

Reference tokens with `css_var` for colors and `css_const` for static values:

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_class :card,
    padding: css_const({MyApp.Tokens, :space, :md}),
    border_radius: css_const({MyApp.Tokens, :radius, :lg}),
    color: css_var({MyApp.Tokens, :colors, :gray_900})
end
```

### Theming

Create theme variations (only works with `css_vars`):

```elixir
# In your tokens
css_theme :semantic, :dark,
  text_primary: css_var({:colors, :white}),
  fill_page: css_var({:colors, :gray_900})

# In your template
<html class={@theme == :dark && css_theme({MyApp.Tokens, :semantic, :dark})}>
```

### Pseudo-classes & Media Queries

```elixir
css_class :link,
  color: [
    default: "blue",
    ":hover": "darkblue"
  ]

css_class :container,
  padding: [
    default: css_const({MyApp.Tokens, :space, :md}),
    "@media (min-width: 768px)": css_const({MyApp.Tokens, :space, :lg})
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
    {:live_style, "~> 0.8.1"},
    # Automatic vendor prefixing
    {:autoprefixer_ex, "~> 0.1.0"},
    # Deprecation warnings for CSS properties
    {:css_compat_data_ex, "~> 0.1.0"}
  ]
end
```

## License

MIT License - see [LICENSE](LICENSE) for details.
