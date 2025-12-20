# Design Tokens

Design tokens are the foundational values of your design system: colors, spacing, typography, and more. LiveStyle provides a structured way to define and reference these tokens.

## Overview

Use `LiveStyle.Tokens` to define:

- **CSS Variables** (`css_vars/2`) - Values that become CSS custom properties (use for colors and themed values)
- **Constants** (`css_consts/2`) - Compile-time values inlined directly into CSS (use for static values)
- **Keyframes** (`css_keyframes/2`) - Animation definitions
- **Typed Variables** - Variables with CSS type information for animation

## When to Use Variables vs Constants

| Use `css_vars` | Use `css_consts` |
|----------------|------------------|
| Colors (for theming) | Spacing scales |
| Semantic tokens (themed) | Font families |
| Values animated via `@property` | Font sizes/weights |
| Values that change at runtime | Border radii |
| | Shadows |
| | Breakpoints |
| | Z-index values |

**Rule of thumb:** If the value might change with a theme or needs to be a CSS variable for animation, use `css_vars`. Otherwise, use `css_consts` for better performance (no CSS variable overhead).

## CSS Variables

Define CSS custom properties with `css_vars/2`. Use for colors and values that need to change:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Colors - use css_vars (needed for theming)
  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_900: "#111827",
    indigo_600: "#4f46e5",
    indigo_700: "#4338ca"

  # Semantic tokens - use css_vars (themed)
  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    text_inverse: css_var({:colors, :white}),
    fill_primary: css_var({:colors, :indigo_600})
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

Use `css_var/1` to reference variables in your styles:

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_class :card,
    background_color: css_var({MyApp.Tokens, :colors, :white}),
    color: css_var({MyApp.Tokens, :semantic, :text_primary})
end
```

### Cross-Referencing Variables

Variables can reference other variables (useful for semantic tokens):

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Raw color palette
  css_vars :colors,
    indigo_600: "#4f46e5",
    gray_900: "#111827"

  # Semantic tokens that reference colors
  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    fill_primary: css_var({:colors, :indigo_600})
end
```

Note: When referencing within the same module, use `{:namespace, :name}` instead of `{Module, :namespace, :name}`.

## Constants

Constants are compile-time values inlined directly into CSS. Use for static values like spacing, typography, radii, and breakpoints:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Spacing - static, use css_consts
  css_consts :space,
    xs: "4px",
    sm: "8px",
    md: "16px",
    lg: "24px",
    xl: "32px"

  # Typography - static, use css_consts
  css_consts :font,
    sans: "Inter, system-ui, sans-serif",
    mono: "JetBrains Mono, monospace"

  css_consts :font_size,
    sm: "0.875rem",
    base: "1rem",
    lg: "1.125rem",
    xl: "1.25rem"

  css_consts :font_weight,
    normal: "400",
    medium: "500",
    semibold: "600",
    bold: "700"

  # Border radius - static, use css_consts
  css_consts :radius,
    sm: "4px",
    md: "8px",
    lg: "12px",
    full: "9999px"

  # Shadows - static, use css_consts
  css_consts :shadow,
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1)"

  # Breakpoints - static, use css_consts
  css_consts :breakpoint,
    sm: "(min-width: 640px)",
    md: "(min-width: 768px)",
    lg: "(min-width: 1024px)",
    xl: "(min-width: 1280px)"

  # Z-index - static, use css_consts
  css_consts :z,
    dropdown: "1000",
    modal: "2000",
    toast: "3000"
end
```

### Using Constants in Styles

Reference constants with `css_const/1`:

```elixir
defmodule MyApp.Button do
  use LiveStyle.Sheet

  css_class :button,
    padding: css_const({MyApp.Tokens, :space, :md}),
    font_size: css_const({MyApp.Tokens, :font_size, :base}),
    font_weight: css_const({MyApp.Tokens, :font_weight, :medium}),
    border_radius: css_const({MyApp.Tokens, :radius, :md})
end
```

### Constants in Media Queries

```elixir
defmodule MyApp.Container do
  use LiveStyle.Sheet

  css_class :container,
    padding: [
      default: css_const({MyApp.Tokens, :space, :md}),
      "@media #{css_const({MyApp.Tokens, :breakpoint, :md})}": css_const({MyApp.Tokens, :space, :lg}),
      "@media #{css_const({MyApp.Tokens, :breakpoint, :lg})}": css_const({MyApp.Tokens, :space, :xl})
    ]
end
```

When using constants as map keys, use the map syntax with `=>`:

```elixir
css_class :responsive,
  font_size: %{
    :default => css_const({MyApp.Tokens, :font_size, :base}),
    css_const({MyApp.Tokens, :breakpoint, :lg}) => css_const({MyApp.Tokens, :font_size, :lg})
  }
```

## Keyframes

Define CSS `@keyframes` animations:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  css_keyframes :spin,
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]

  css_keyframes :pulse,
    "0%": [opacity: "1"],
    "50%": [opacity: "0.5"],
    "100%": [opacity: "1"]

  css_keyframes :bounce,
    "0%, 100%": [
      transform: "translateY(-25%)",
      animation_timing_function: "cubic-bezier(0.8, 0, 1, 1)"
    ],
    "50%": [
      transform: "translateY(0)",
      animation_timing_function: "cubic-bezier(0, 0, 0.2, 1)"
    ]
end
```

### Using Keyframes

Reference keyframes with `css_keyframes/1`:

```elixir
defmodule MyApp.Spinner do
  use LiveStyle.Sheet

  css_class :spinner,
    animation: "#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"

  css_class :pulsing,
    animation: "#{css_keyframes({MyApp.Tokens, :pulse})} 2s ease-in-out infinite"
end
```

## Typed Variables

For advanced use cases like animating gradients, you can specify the CSS type. These must be `css_vars` since they need `@property` rules:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  import LiveStyle.Types

  # Typed variables for animation - must use css_vars
  css_vars :anim,
    rotation: angle("0deg"),
    progress: percentage("0%")
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
| `color/1` | `<color>` |
| `length/1` | `<length>` |
| `angle/1` | `<angle>` |
| `integer/1` | `<integer>` |
| `number/1` | `<number>` |
| `time/1` | `<time>` |
| `percentage/1` | `<percentage>` |

## Recommended Token Structure

A recommended structure for larger applications:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  import LiveStyle.Types

  # =========================================
  # CSS Variables (values that can change)
  # =========================================

  # Colors - raw palette
  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_900: "#111827",
    indigo_500: "#6366f1",
    indigo_600: "#4f46e5"

  # Semantic tokens - themed
  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    text_inverse: css_var({:colors, :white}),
    fill_page: css_var({:colors, :white}),
    fill_surface: css_var({:colors, :gray_50}),
    fill_primary: css_var({:colors, :indigo_600})

  # Dark theme overrides
  css_theme :semantic, :dark,
    text_primary: css_var({:colors, :gray_50}),
    text_inverse: css_var({:colors, :gray_900}),
    fill_page: css_var({:colors, :gray_900}),
    fill_surface: css_var({:colors, :gray_900}),
    fill_primary: css_var({:colors, :indigo_500})

  # Typed variables for animation
  css_vars :anim,
    rotation: angle("0deg")

  # =========================================
  # Constants (static values)
  # =========================================

  css_consts :space,
    px: "1px",
    xs: "4px",
    sm: "8px",
    md: "16px",
    lg: "24px",
    xl: "32px"

  css_consts :font,
    sans: "Inter, system-ui, sans-serif",
    mono: "JetBrains Mono, monospace"

  css_consts :font_size,
    xs: "0.75rem",
    sm: "0.875rem",
    base: "1rem",
    lg: "1.125rem",
    xl: "1.25rem"

  css_consts :font_weight,
    normal: "400",
    medium: "500",
    semibold: "600",
    bold: "700"

  css_consts :radius,
    sm: "4px",
    md: "8px",
    lg: "12px",
    xl: "16px",
    full: "9999px"

  css_consts :shadow,
    sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    md: "0 4px 6px -1px rgb(0 0 0 / 0.1)"

  css_consts :breakpoint,
    sm: "(min-width: 640px)",
    md: "(min-width: 768px)",
    lg: "(min-width: 1024px)"

  css_consts :z,
    dropdown: "1000",
    modal: "2000",
    toast: "3000"

  # =========================================
  # Keyframes
  # =========================================

  css_keyframes :fade_in,
    from: [opacity: "0"],
    to: [opacity: "1"]

  css_keyframes :slide_up,
    from: [transform: "translateY(10px)", opacity: "0"],
    to: [transform: "translateY(0)", opacity: "1"]
end
```

## Next Steps

- [Styling Components](styling-components.md) - Use tokens in component styles
- [Theming](theming.md) - Override semantic tokens with themes
