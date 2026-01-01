# Design Tokens

Design tokens are the foundational values of your design system: colors, spacing, typography, and more. LiveStyle provides a structured way to define and reference these tokens.

## Overview

LiveStyle uses a module-as-namespace pattern for tokens:

- **CSS Variables** (`vars`) - Values that become CSS custom properties (use for colors and themed values)
- **Constants** (`consts`) - Compile-time values inlined directly into CSS (use for static values)
- **Keyframes** (`keyframes`) - Animation definitions
- **Typed Variables** - Variables with CSS type information for animation

## When to Use Variables vs Constants

| Use `vars` | Use `consts` |
|----------------|------------------|
| Colors (for theming) | Spacing scales (unless themeable) |
| Semantic tokens (themed) | Font families |
| Values animated via `@property` | Font sizes/weights |
| Values that change at runtime | Border radii |
| | Shadows |
| | Breakpoints |
| | Z-index values |

**Rule of thumb:** If the value might change with a theme or needs to be animated, use `vars`. Otherwise, use `consts` for better performance.

## CSS Variables

Define CSS custom properties with `vars`. Each module defines its own tokens:

```elixir
defmodule MyApp.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_900: "#111827",
    indigo_600: "#4f46e5",
    indigo_700: "#4338ca"
  ]
end

defmodule MyApp.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyApp.Colors, :gray_900}),
    text_inverse: var({MyApp.Colors, :white}),
    fill_primary: var({MyApp.Colors, :indigo_600})
  ]
end
```

This generates CSS like:

```css
:root {
  --v1abc123: #ffffff;
  --v2def456: #000000;
  /* ... */
}
```

### Referencing Variables

Use `var/1` to reference variables in your styles:

```elixir
defmodule MyApp.Card do
  use LiveStyle

  class :card,
    background_color: var({MyApp.Colors, :white}),
    color: var({MyApp.Semantic, :text_primary})
end
```

## Constants

Constants are compile-time values inlined directly into CSS. Define each category in its own module:

```elixir
defmodule MyApp.Spacing do
  use LiveStyle

  consts [
    xs: "4px",
    sm: "8px",
    md: "16px",
    lg: "24px",
    xl: "32px"
  ]
end

defmodule MyApp.FontSize do
  use LiveStyle

  consts [
    sm: "0.875rem",
    base: "1rem",
    lg: "1.125rem",
    xl: "1.25rem"
  ]
end

defmodule MyApp.Radius do
  use LiveStyle

  consts [
    sm: "4px",
    md: "8px",
    lg: "12px",
    full: "9999px"
  ]
end

defmodule MyApp.Shadow do
  use LiveStyle

  consts [
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1)"
  ]
end

defmodule MyApp.Breakpoints do
  use LiveStyle

  consts [
    sm: "@media (min-width: 640px)",
    md: "@media (min-width: 768px)",
    lg: "@media (min-width: 1024px)",
    xl: "@media (min-width: 1280px)"
  ]
end

defmodule MyApp.ZIndex do
  use LiveStyle

  consts [
    dropdown: "1000",
    modal: "2000",
    toast: "3000"
  ]
end
```

### Using Constants in Styles

Reference constants with `const/1`:

```elixir
defmodule MyApp.Button do
  use LiveStyle

  class :button,
    padding: const({MyApp.Spacing, :md}),
    font_size: const({MyApp.FontSize, :base}),
    border_radius: const({MyApp.Radius, :md})
end
```

### Constants in Media Queries

```elixir
defmodule MyApp.Container do
  use LiveStyle

  class :container,
    padding: %{
      :default => const({MyApp.Spacing, :md}),
      const({MyApp.Breakpoints, :md}) => const({MyApp.Spacing, :lg}),
      const({MyApp.Breakpoints, :lg}) => const({MyApp.Spacing, :xl})
    }
end
```

## Keyframes

Define CSS `@keyframes` animations:

```elixir
defmodule MyApp.Animations do
  use LiveStyle

  keyframes :spin, [
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
  ]

  keyframes :pulse, [
    "0%": [opacity: "1"],
    "50%": [opacity: "0.5"],
    "100%": [opacity: "1"]
  ]

  keyframes :bounce, [
    "0%, 100%": [
      transform: "translateY(-25%)",
      animation_timing_function: "cubic-bezier(0.8, 0, 1, 1)"
    ],
    "50%": [
      transform: "translateY(0)",
      animation_timing_function: "cubic-bezier(0, 0, 0.2, 1)"
    ]
  ]
end
```

### Using Keyframes

Reference keyframes with `keyframes/1`:

```elixir
defmodule MyApp.Spinner do
  use LiveStyle

  class :spinner,
    animation: "#{keyframes({MyApp.Animations, :spin})} 1s linear infinite"

  class :pulsing,
    animation: "#{keyframes({MyApp.Animations, :pulse})} 2s ease-in-out infinite"
end
```

## Typed Variables

For animating CSS properties like gradients, specify the CSS type using `LiveStyle.CSS.Property`:

```elixir
defmodule MyApp.Animation do
  use LiveStyle
  alias LiveStyle.CSS.Property

  vars [
    rotation: Property.angle("0deg"),
    progress: Property.percentage("0%")
  ]
end
```

This generates CSS `@property` rules that enable browsers to interpolate these values:

```css
@property --v1abc123 {
  syntax: "<angle>";
  inherits: true;
  initial-value: 0deg;
}
```

### Available Types

| Function | CSS Syntax |
|----------|------------|
| `Property.color/1` | `<color>` |
| `Property.length/1` | `<length>` |
| `Property.angle/1` | `<angle>` |
| `Property.integer/1` | `<integer>` |
| `Property.number/1` | `<number>` |
| `Property.time/1` | `<time>` |
| `Property.percentage/1` | `<percentage>` |

## Recommended Token Structure

A recommended structure for larger applications:

```
lib/my_app/tokens/
├── colors.ex          # MyApp.Colors - raw color palette
├── semantic.ex        # MyApp.Semantic - themed semantic tokens
├── spacing.ex         # MyApp.Spacing - spacing scale
├── font_size.ex       # MyApp.FontSize - typography sizes
├── radius.ex          # MyApp.Radius - border radii
├── shadow.ex          # MyApp.Shadow - box shadows
├── breakpoints.ex     # MyApp.Breakpoints - media queries
├── z_index.ex         # MyApp.ZIndex - z-index values
└── animations.ex      # MyApp.Animations - keyframes
```

Example Colors module:

```elixir
defmodule MyApp.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_100: "#f3f4f6",
    gray_900: "#111827",
    indigo_500: "#6366f1",
    indigo_600: "#4f46e5"
  ]
end
```

Example Semantic module with theme:

```elixir
defmodule MyApp.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyApp.Colors, :gray_900}),
    text_inverse: var({MyApp.Colors, :white}),
    fill_page: var({MyApp.Colors, :white}),
    fill_surface: var({MyApp.Colors, :gray_50}),
    fill_primary: var({MyApp.Colors, :indigo_600})
  ]

  theme :dark, [
    text_primary: var({MyApp.Colors, :gray_50}),
    text_inverse: var({MyApp.Colors, :gray_900}),
    fill_page: var({MyApp.Colors, :gray_900}),
    fill_surface: var({MyApp.Colors, :gray_900}),
    fill_primary: var({MyApp.Colors, :indigo_500})
  ]
end
```

## Next Steps

- [Styling Components](styling-components.md) - Use tokens in component styles
- [Theming](theming.md) - Override semantic tokens with themes
