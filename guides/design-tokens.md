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
defmodule MyAppWeb.Colors do
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

defmodule MyAppWeb.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyAppWeb.Colors, :gray_900}),
    text_inverse: var({MyAppWeb.Colors, :white}),
    fill_primary: var({MyAppWeb.Colors, :indigo_600})
  ]
end
```

### Referencing Variables

Use `var/1` to reference variables in your styles:

```elixir
defmodule MyAppWeb.Card do
  use LiveStyle

  class :card,
    background_color: var({MyAppWeb.Colors, :white}),
    color: var({MyAppWeb.Semantic, :text_primary})
end
```

## Constants

Constants are compile-time values inlined directly into CSS. Define each category in its own module:

```elixir
defmodule MyAppWeb.Spacing do
  use LiveStyle

  consts [
    xs: "4px",
    sm: "8px",
    md: "16px",
    lg: "24px",
    xl: "32px"
  ]
end

defmodule MyAppWeb.FontSize do
  use LiveStyle

  consts [
    sm: "0.875rem",
    base: "1rem",
    lg: "1.125rem",
    xl: "1.25rem"
  ]
end

defmodule MyAppWeb.Radius do
  use LiveStyle

  consts [
    sm: "4px",
    md: "8px",
    lg: "12px",
    full: "9999px"
  ]
end

defmodule MyAppWeb.Shadow do
  use LiveStyle

  consts [
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1)"
  ]
end

defmodule MyAppWeb.Breakpoints do
  use LiveStyle

  consts [
    sm: "@media (min-width: 640px)",
    md: "@media (min-width: 768px)",
    lg: "@media (min-width: 1024px)",
    xl: "@media (min-width: 1280px)"
  ]
end

defmodule MyAppWeb.ZIndex do
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
defmodule MyAppWeb.Button do
  use LiveStyle

  class :button,
    padding: const({MyAppWeb.Spacing, :md}),
    font_size: const({MyAppWeb.FontSize, :base}),
    border_radius: const({MyAppWeb.Radius, :md})
end
```

### Constants in Media Queries

```elixir
defmodule MyAppWeb.Container do
  use LiveStyle

  class :container,
    padding: [
      default: const({MyAppWeb.Spacing, :md}),
      "@media #{const({MyAppWeb.Breakpoints, :md})}": const({MyAppWeb.Spacing, :lg}),
      "@media #{const({MyAppWeb.Breakpoints, :lg})}": const({MyAppWeb.Spacing, :xl})
    ]
end
```

## Keyframes

Define CSS `@keyframes` animations:

```elixir
defmodule MyAppWeb.Animations do
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
defmodule MyAppWeb.Spinner do
  use LiveStyle

  class :spinner,
    animation: "#{keyframes({MyAppWeb.Animations, :spin})} 1s linear infinite"

  class :pulsing,
    animation: "#{keyframes({MyAppWeb.Animations, :pulse})} 2s ease-in-out infinite"
end
```

## Typed Variables

For animating CSS properties like gradients, specify the CSS type using `LiveStyle.Types`. This generates CSS `@property` rules that enable browsers to interpolate these values:

```elixir
defmodule MyAppWeb.Animation do
  use LiveStyle
  import LiveStyle.Types

  vars rotation: angle("0deg"),
       progress: percentage("0%")
end
```

### Available Types

| Function | CSS Syntax |
|----------|------------|
| `color/1` | `<color>` |
| `length/1` | `<length>` |
| `angle/1` | `<angle>` |
| `integer/1` | `<integer>` |
| `number/1` | `<number>` |
| `time/1` | `<time>` |
| `percentage/1` | `<percentage>` |

## Recommended Token Structure

A recommended structure for larger applications:

```
lib/my_app/tokens/
├── colors.ex          # MyAppWeb.Colors - raw color palette
├── semantic.ex        # MyAppWeb.Semantic - themed semantic tokens
├── spacing.ex         # MyAppWeb.Spacing - spacing scale
├── font_size.ex       # MyAppWeb.FontSize - typography sizes
├── radius.ex          # MyAppWeb.Radius - border radii
├── shadow.ex          # MyAppWeb.Shadow - box shadows
├── breakpoints.ex     # MyAppWeb.Breakpoints - media queries
├── z_index.ex         # MyAppWeb.ZIndex - z-index values
└── animations.ex      # MyAppWeb.Animations - keyframes
```

Example Colors module:

```elixir
defmodule MyAppWeb.Colors do
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
defmodule MyAppWeb.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyAppWeb.Colors, :gray_900}),
    text_inverse: var({MyAppWeb.Colors, :white}),
    fill_page: var({MyAppWeb.Colors, :white}),
    fill_surface: var({MyAppWeb.Colors, :gray_50}),
    fill_primary: var({MyAppWeb.Colors, :indigo_600})
  ]

  theme_class :dark, [
    text_primary: var({MyAppWeb.Colors, :gray_50}),
    text_inverse: var({MyAppWeb.Colors, :gray_900}),
    fill_page: var({MyAppWeb.Colors, :gray_900}),
    fill_surface: var({MyAppWeb.Colors, :gray_900}),
    fill_primary: var({MyAppWeb.Colors, :indigo_500})
  ]
end
```

## Next Steps

- [Styling Components](styling-components.md) - Use tokens in component styles
- [Theming](theming.md) - Override semantic tokens with themes
