# Theming

LiveStyle provides a powerful theming system that allows you to override CSS variables for different contexts, such as dark mode or high contrast themes.

## The Theming Pattern

The standard pattern uses two layers:

1. **Colors** - Raw color palette using `vars` (hex values)
2. **Semantic tokens** - Abstract meanings that reference colors via `var` (themed)

This separation keeps color values in one place while allowing themes to swap which colors semantic tokens point to.

> **Note:** Only values defined with `vars` can be themed. Many teams keep spacing/typography/radii as `consts`, but if you want themeable spacing scales (e.g. compact/cozy), define them with `vars` and override with `theme`.

## Defining Themes

Using the module-as-namespace pattern, define colors in one module and semantic tokens in another:

```elixir
defmodule MyApp.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_100: "#f3f4f6",
    gray_800: "#1f2937",
    gray_900: "#111827",
    indigo_500: "#6366f1",
    indigo_600: "#4f46e5"
  ]
end

defmodule MyApp.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyApp.Colors, :gray_900}),
    text_secondary: var({MyApp.Colors, :gray_800}),
    text_inverse: var({MyApp.Colors, :white}),
    fill_page: var({MyApp.Colors, :white}),
    fill_surface: var({MyApp.Colors, :gray_50}),
    fill_primary: var({MyApp.Colors, :indigo_600}),
    fill_primary_hover: var({MyApp.Colors, :indigo_500})
  ]

  # Dark theme overrides
  theme :dark, [
    text_primary: var({MyApp.Colors, :gray_50}),
    text_secondary: var({MyApp.Colors, :gray_100}),
    text_inverse: var({MyApp.Colors, :gray_900}),
    fill_page: var({MyApp.Colors, :gray_900}),
    fill_surface: var({MyApp.Colors, :gray_800}),
    fill_primary: var({MyApp.Colors, :indigo_500}),
    fill_primary_hover: var({MyApp.Colors, :indigo_600})
  ]
end

defmodule MyApp.Spacing do
  use LiveStyle

  consts [
    sm: "8px",
    md: "16px",
    lg: "24px"
  ]
end

defmodule MyApp.Radius do
  use LiveStyle

  consts [
    md: "8px",
    lg: "12px"
  ]
end
```

## Using Semantic Tokens

Components reference semantic tokens for colors, constants for static values:

```elixir
defmodule MyApp.Card do
  use LiveStyle

  class :card,
    # Colors use var (themed)
    background_color: var({MyApp.Semantic, :fill_surface}),
    color: var({MyApp.Semantic, :text_primary}),
    # Static values use const (not themed)
    padding: const({MyApp.Spacing, :md}),
    border_radius: const({MyApp.Radius, :lg})
end

defmodule MyApp.Button do
  use LiveStyle

  class :primary,
    background_color: var({MyApp.Semantic, :fill_primary}),
    color: var({MyApp.Semantic, :text_inverse}),
    padding: const({MyApp.Spacing, :md}),
    border_radius: const({MyApp.Radius, :md}),
    ":hover": [
      background_color: var({MyApp.Semantic, :fill_primary_hover})
    ]
end
```

Components don't need to know about themes - they just use semantic tokens for colors.

## Applying Themes

Use `theme/1` to apply a theme to a subtree:

```heex
<div class={theme({MyApp.Semantic, :dark})}>
  <!-- All children use dark theme colors -->
  <.card>
    <p>This card uses dark theme colors</p>
    <.button>Dark button</.button>
  </.card>
</div>
```

### App-Wide Theme Toggle

Apply the theme at the root level:

```heex
<!-- In root.html.heex -->
<html class={@theme == :dark && theme({MyApp.Semantic, :dark})}>
  <head>
    <!-- ... -->
  </head>
  <body {css({MyApp.Layout, :body})}>
    <%= @inner_content %>
  </body>
</html>
```

### Respecting System Preference

For automatic system preference, use JavaScript to detect and set a class on the `<html>` element:

```javascript
// Check system preference
if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
  document.documentElement.classList.add('dark-theme');
}
```

Then apply the theme conditionally in your template.

## Multiple Themes

Define multiple themes for different contexts:

```elixir
defmodule MyApp.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    yellow_400: "#facc15"
  ]
end

defmodule MyApp.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyApp.Colors, :gray_900}),
    fill_page: var({MyApp.Colors, :white})
  ]

  # Dark theme
  theme :dark, [
    text_primary: var({MyApp.Colors, :white}),
    fill_page: var({MyApp.Colors, :gray_900})
  ]

  # High contrast theme
  theme :high_contrast, [
    text_primary: var({MyApp.Colors, :black}),
    fill_page: var({MyApp.Colors, :white})
  ]

  # Special promotion theme
  theme :promo, [
    text_primary: var({MyApp.Colors, :black}),
    fill_page: var({MyApp.Colors, :yellow_400})
  ]
end
```

Use different themes in different parts of your app:

```heex
<main>
  <!-- Default theme -->
  <.hero />

  <!-- Promotional section -->
  <section class={theme({MyApp.Semantic, :promo})}>
    <.promo_banner />
  </section>

  <!-- Footer with dark theme -->
  <footer class={theme({MyApp.Semantic, :dark})}>
    <.footer_content />
  </footer>
</main>
```

## Nested Themes

Themes can be nested - inner themes override outer ones:

```heex
<div class={theme({MyApp.Semantic, :dark})}>
  <!-- Dark theme -->
  <.card>Dark card</.card>

  <div class={theme({MyApp.Semantic, :high_contrast})}>
    <!-- High contrast theme (overrides dark) -->
    <.card>High contrast card</.card>
  </div>
</div>
```

## Generated CSS

Themes generate CSS that overrides the base variables:

```css
/* Base semantic tokens */
:root {
  --v1abc123: var(--v2def456); /* text_primary references gray_900 */
  --v3ghi789: var(--v4jkl012); /* fill_page references white */
}

/* Dark theme overrides */
.x1dark2theme {
  --v1abc123: var(--v5mno345); /* text_primary now references gray_50 */
  --v3ghi789: var(--v2def456); /* fill_page now references gray_900 */
}
```

When you apply `theme({MyApp.Semantic, :dark})`, it returns a class name like `x1dark2theme` that overrides the CSS variables for that element and all its descendants.

## Theme-Aware Components

Sometimes you need different behavior based on the active theme. While components shouldn't need to know about themes for basic styling (that's what semantic tokens are for), you might need theme awareness for:

- Icons that need different assets
- Complex components with non-CSS differences

For these cases, pass the theme as a prop:

```elixir
def logo(assigns) do
  ~H"""
  <img src={logo_src(@theme)} alt="Logo" />
  """
end

defp logo_src(:dark), do: ~p"/images/logo-light.svg"
defp logo_src(_), do: ~p"/images/logo-dark.svg"
```

## Best Practices

1. **Use semantic tokens for colors** - Don't reference color primitives directly in components
2. **Use constants for static values** - Spacing, typography, radii don't need theming
3. **Keep primitives stable** - Themes override semantics, not primitives
4. **Name semantically** - Use `fill_primary` not `fill_blue`
5. **Test all themes** - Ensure components look good in every theme
6. **Consider accessibility** - Ensure sufficient contrast in all themes

## Next Steps

- [Advanced Features](advanced-features.md) - Contextual selectors and view transitions
- [Configuration](configuration.md) - CSS layers and other options
