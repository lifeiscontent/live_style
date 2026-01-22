# Theming

LiveStyle provides a powerful theming system that allows you to override CSS variables for different contexts, such as dark mode or high contrast themes.

## The Theming Pattern

The standard pattern uses two layers:

1. **Colors** - Raw color palette using `vars` (hex values)
2. **Semantic tokens** - Abstract meanings that reference colors via `var` (themed)

This separation keeps color values in one place while allowing themes to swap which colors semantic tokens point to.

> **Note:** Only values defined with `vars` can be themed. Many teams keep spacing/typography/radii as `consts`, but if you want themeable spacing scales (e.g. compact/cozy), define them with `vars` and override with `theme_class`.

## Defining Themes

Using the module-as-namespace pattern, define colors in one module and semantic tokens in another:

```elixir
defmodule MyAppWeb.Colors do
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

defmodule MyAppWeb.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyAppWeb.Colors, :gray_900}),
    text_secondary: var({MyAppWeb.Colors, :gray_800}),
    text_inverse: var({MyAppWeb.Colors, :white}),
    fill_page: var({MyAppWeb.Colors, :white}),
    fill_surface: var({MyAppWeb.Colors, :gray_50}),
    fill_primary: var({MyAppWeb.Colors, :indigo_600}),
    fill_primary_hover: var({MyAppWeb.Colors, :indigo_500})
  ]

  # Dark theme overrides
  theme_class :dark, [
    text_primary: var({MyAppWeb.Colors, :gray_50}),
    text_secondary: var({MyAppWeb.Colors, :gray_100}),
    text_inverse: var({MyAppWeb.Colors, :gray_900}),
    fill_page: var({MyAppWeb.Colors, :gray_900}),
    fill_surface: var({MyAppWeb.Colors, :gray_800}),
    fill_primary: var({MyAppWeb.Colors, :indigo_500}),
    fill_primary_hover: var({MyAppWeb.Colors, :indigo_600})
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
    md: "8px",
    lg: "12px"
  ]
end
```

## Using Semantic Tokens

Components reference semantic tokens for colors, constants for static values:

```elixir
defmodule MyAppWeb.Card do
  use LiveStyle

  class :card,
    # Colors use var (themed)
    background_color: var({MyAppWeb.Semantic, :fill_surface}),
    color: var({MyAppWeb.Semantic, :text_primary}),
    # Static values use const (not themed)
    padding: const({MyAppWeb.Spacing, :md}),
    border_radius: const({MyAppWeb.Radius, :lg})
end

defmodule MyAppWeb.Button do
  use LiveStyle

  class :primary,
    background_color: var({MyAppWeb.Semantic, :fill_primary}),
    color: var({MyAppWeb.Semantic, :text_inverse}),
    padding: const({MyAppWeb.Spacing, :md}),
    border_radius: const({MyAppWeb.Radius, :md}),
    ":hover": [
      background_color: var({MyAppWeb.Semantic, :fill_primary_hover})
    ]
end
```

Components don't need to know about themes - they just use semantic tokens for colors.

## Applying Themes

Use `theme_class/1` to apply a theme to a subtree:

```heex
<div class={theme_class({MyAppWeb.Semantic, :dark})}>
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
<html class={@theme == :dark && theme_class({MyAppWeb.Semantic, :dark})}>
  <head>
    <!-- ... -->
  </head>
  <body {css({MyAppWeb.Layout, :body})}>
    <%= @inner_content %>
  </body>
</html>
```

### JavaScript Integration

Since theme class names are generated at compile time, you need to bridge them to JavaScript for runtime theme switching. Use data attributes to pass the class names:

```heex
<!-- In root.html.heex -->
<html
  lang="en"
  data-theme-dark={theme_class({MyAppWeb.Semantic, :dark})}
  data-theme-light={theme_class({MyAppWeb.Semantic, :light})}
>
```

Then in a blocking `<script>` tag in `<head>` (to prevent flash of unstyled content):

```heex
<script>
  (function() {
    const html = document.documentElement;
    const themes = {
      dark: html.dataset.themeDark,
      light: html.dataset.themeLight
    };

    const getStoredTheme = () => localStorage.getItem("theme");
    const getSystemTheme = () =>
      window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

    const applyTheme = (theme) => {
      // Remove all theme classes
      Object.values(themes).forEach(cls => cls && html.classList.remove(cls));

      // Apply the appropriate theme class
      if (theme === "system") {
        const systemTheme = getSystemTheme();
        if (themes[systemTheme]) html.classList.add(themes[systemTheme]);
      } else if (themes[theme]) {
        html.classList.add(themes[theme]);
      }
    };

    // Apply theme immediately on page load
    const stored = getStoredTheme();
    applyTheme(stored || "system");

    // Listen for system preference changes
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      if (!getStoredTheme() || getStoredTheme() === "system") {
        applyTheme("system");
      }
    });

    // Expose setTheme for UI controls
    window.setTheme = (theme) => {
      if (theme === "system") {
        localStorage.removeItem("theme");
      } else {
        localStorage.setItem("theme", theme);
      }
      applyTheme(theme);
    };
  })();
</script>
```

### Theme Toggle Component

Create a theme toggle that works with the JavaScript bridge:

```elixir
defmodule MyAppWeb.ThemeToggle do
  use Phoenix.Component

  def toggle(assigns) do
    ~H"""
    <div>
      <button type="button" onclick="setTheme('system')">System</button>
      <button type="button" onclick="setTheme('light')">Light</button>
      <button type="button" onclick="setTheme('dark')">Dark</button>
    </div>
    """
  end
end
```

For LiveView integration, use `JS.dispatch/1`:

```elixir
def toggle(assigns) do
  ~H"""
  <div>
    <button type="button" phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}>
      System
    </button>
    <button type="button" phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}>
      Light
    </button>
    <button type="button" phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}>
      Dark
    </button>
  </div>
  """
end
```

And handle the event in JavaScript:

```javascript
window.addEventListener("phx:set-theme", (e) => {
  window.setTheme(e.detail.theme);
});
```

### Why Data Attributes?

You might wonder why we pass class names via data attributes instead of hardcoding them. LiveStyle generates hashed class names (like `x1a2b3c4`) at compile time. By using data attributes:

1. **No duplication** - The class name is defined once in Elixir
2. **No sync issues** - JS always reads the current class name
3. **Refactor-safe** - Changing theme definitions won't break JS

## Multiple Themes

Define multiple themes for different contexts:

```elixir
defmodule MyAppWeb.Colors do
  use LiveStyle

  vars [
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    yellow_400: "#facc15"
  ]
end

defmodule MyAppWeb.Semantic do
  use LiveStyle

  vars [
    text_primary: var({MyAppWeb.Colors, :gray_900}),
    fill_page: var({MyAppWeb.Colors, :white})
  ]

  # Dark theme
  theme_class :dark, [
    text_primary: var({MyAppWeb.Colors, :white}),
    fill_page: var({MyAppWeb.Colors, :gray_900})
  ]

  # High contrast theme
  theme_class :high_contrast, [
    text_primary: var({MyAppWeb.Colors, :black}),
    fill_page: var({MyAppWeb.Colors, :white})
  ]

  # Special promotion theme
  theme_class :promo, [
    text_primary: var({MyAppWeb.Colors, :black}),
    fill_page: var({MyAppWeb.Colors, :yellow_400})
  ]
end
```

Use different themes in different parts of your app:

```heex
<main>
  <!-- Default theme -->
  <.hero />

  <!-- Promotional section -->
  <section class={theme_class({MyAppWeb.Semantic, :promo})}>
    <.promo_banner />
  </section>

  <!-- Footer with dark theme -->
  <footer class={theme_class({MyAppWeb.Semantic, :dark})}>
    <.footer_content />
  </footer>
</main>
```

## Nested Themes

Themes can be nested - inner themes override outer ones:

```heex
<div class={theme_class({MyAppWeb.Semantic, :dark})}>
  <!-- Dark theme -->
  <.card>Dark card</.card>

  <div class={theme_class({MyAppWeb.Semantic, :high_contrast})}>
    <!-- High contrast theme (overrides dark) -->
    <.card>High contrast card</.card>
  </div>
</div>
```

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
