# Theming

LiveStyle provides a powerful theming system that allows you to override CSS variables for different contexts, such as dark mode or high contrast themes.

## The Theming Pattern

The standard pattern uses two layers:

1. **Colors** - Raw color palette using `css_vars` (hex values)
2. **Semantic tokens** - Abstract meanings that reference colors via `css_var` (themed)

This separation keeps color values in one place while allowing themes to swap which colors semantic tokens point to.

> **Note:** Only values defined with `css_vars` can be themed. Many teams keep spacing/typography/radii as `css_consts`, but if you want themeable spacing scales (e.g. compact/cozy), define them with `css_vars` and override with `css_theme/3`.

## Defining Themes

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # === Colors (css_vars - needed for theming) ===
  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_50: "#f9fafb",
    gray_100: "#f3f4f6",
    gray_800: "#1f2937",
    gray_900: "#111827",
    indigo_500: "#6366f1",
    indigo_600: "#4f46e5"

  # === Semantic tokens (css_vars - themed) ===
  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    text_secondary: css_var({:colors, :gray_800}),
    text_inverse: css_var({:colors, :white}),
    fill_page: css_var({:colors, :white}),
    fill_surface: css_var({:colors, :gray_50}),
    fill_primary: css_var({:colors, :indigo_600}),
    fill_primary_hover: css_var({:colors, :indigo_500})

  # === Dark theme ===
  css_theme :semantic, :dark,
    text_primary: css_var({:colors, :gray_50}),
    text_secondary: css_var({:colors, :gray_100}),
    text_inverse: css_var({:colors, :gray_900}),
    fill_page: css_var({:colors, :gray_900}),
    fill_surface: css_var({:colors, :gray_800}),
    fill_primary: css_var({:colors, :indigo_500}),
    fill_primary_hover: css_var({:colors, :indigo_600})

  # === Static values (css_consts - not themed) ===
  css_consts :space,
    sm: "8px",
    md: "16px",
    lg: "24px"

  css_consts :radius,
    md: "8px",
    lg: "12px"
end
```

## Using Semantic Tokens

Components reference semantic tokens for colors, constants for static values:

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_class :card,
    # Colors use css_var (themed)
    background_color: css_var({MyApp.Tokens, :semantic, :fill_surface}),
    color: css_var({MyApp.Tokens, :semantic, :text_primary}),
    # Static values use css_const (not themed)
    padding: css_const({MyApp.Tokens, :space, :md}),
    border_radius: css_const({MyApp.Tokens, :radius, :lg})
end

defmodule MyApp.Button do
  use LiveStyle.Sheet

  css_class :primary,
    background_color: css_var({MyApp.Tokens, :semantic, :fill_primary}),
    color: css_var({MyApp.Tokens, :semantic, :text_inverse}),
    padding: css_const({MyApp.Tokens, :space, :md}),
    border_radius: css_const({MyApp.Tokens, :radius, :md}),
    ":hover": [
      background_color: css_var({MyApp.Tokens, :semantic, :fill_primary_hover})
    ]
end
```

Components don't need to know about themes - they just use semantic tokens for colors.

## Applying Themes

Use `css_theme/1` to apply a theme to a subtree:

```heex
<div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
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
<html class={@theme == :dark && css_theme({MyApp.Tokens, :semantic, :dark})}>
  <head>
    <!-- ... -->
  </head>
  <body class={css_class({MyApp.Layout, :body})}>
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
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    yellow_400: "#facc15"

  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    fill_page: css_var({:colors, :white})

  # Dark theme
  css_theme :semantic, :dark,
    text_primary: css_var({:colors, :white}),
    fill_page: css_var({:colors, :gray_900})

  # High contrast theme
  css_theme :semantic, :high_contrast,
    text_primary: css_var({:colors, :black}),
    fill_page: css_var({:colors, :white})

  # Special promotion theme
  css_theme :semantic, :promo,
    text_primary: css_var({:colors, :black}),
    fill_page: css_var({:colors, :yellow_400})
end
```

Use different themes in different parts of your app:

```heex
<main>
  <!-- Default theme -->
  <.hero />
  
  <!-- Promotional section -->
  <section class={css_theme({MyApp.Tokens, :semantic, :promo})}>
    <.promo_banner />
  </section>
  
  <!-- Footer with dark theme -->
  <footer class={css_theme({MyApp.Tokens, :semantic, :dark})}>
    <.footer_content />
  </footer>
</main>
```

## Nested Themes

Themes can be nested - inner themes override outer ones:

```heex
<div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
  <!-- Dark theme -->
  <.card>Dark card</.card>
  
  <div class={css_theme({MyApp.Tokens, :semantic, :high_contrast})}>
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
  --semantic-text-primary: var(--colors-gray-900);
  --semantic-fill-page: var(--colors-white);
}

/* Dark theme overrides */
.x1dark2theme {
  --semantic-text-primary: var(--colors-white);
  --semantic-fill-page: var(--colors-gray-900);
}
```

When you apply `css_theme({MyApp.Tokens, :semantic, :dark})`, it returns a class name like `x1dark2theme` that overrides the CSS variables for that element and all its descendants.

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
