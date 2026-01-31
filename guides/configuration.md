# Configuration

This guide covers LiveStyle's configuration options.

## Basic Configuration

Configure LiveStyle in `config/config.exs`:

```elixir
config :live_style,
  my_app: [
    input: "assets/css/app.css",
    output: "priv/static/assets/css/app.css"
  ]
```

With optional integrations:

```elixir
config :live_style,
  # Automatic vendor prefixing
  prefix_css: {AutoprefixerEx, :prefix_css},
  # Deprecation warnings
  deprecated?: {CSSCompatDataEx, :deprecated?},
  # Profile (name it after your app)
  my_app: [
    input: "assets/css/app.css",
    output: "priv/static/assets/css/app.css"
  ]
```

## Import Directive

LiveStyle uses `@import "live_style"` to inject CSS into your stylesheet—the same pattern as Tailwind 4's `@import "tailwindcss"`.

```css
/* assets/css/app.css */

/* Your reset styles */
@layer reset {
  *, *::before, *::after { box-sizing: border-box; }
  * { margin: 0; padding: 0; }
}

/* LiveStyle output injected here */
@import "live_style";

/* Your custom overrides */
.my-override { color: red; }
```

LiveStyle reads the input file, replaces the directive with generated CSS, and writes to the output path.

### Directive Variants

All of these work:

- `@import "live_style";`
- `@import "live_style"`
- `@import 'live_style';`
- `@import 'live_style'`

### Missing Directive Error

If the directive isn't found:

```
** (ArgumentError) Could not find @import "live_style" directive in assets/css/app.css.

Add this line where you want LiveStyle CSS to be injected:

    @import "live_style";
```

## Multiple Profiles

Define profiles for different outputs:

```elixir
config :live_style,
  my_app: [
    input: "assets/css/app.css",
    output: "priv/static/assets/css/app.css"
  ],
  admin: [
    input: "assets/css/admin.css",
    output: "priv/static/assets/css/admin.css"
  ]
```

Generate for a specific profile:

```bash
mix live_style my_app
mix live_style admin
```

In aliases:

```elixir
defp aliases do
  [
    "assets.build": ["compile", "live_style my_app", "live_style admin", "esbuild my_app"]
  ]
end
```

## Development Watcher

Add to `config/dev.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    live_style: {LiveStyle, :install_and_run, [:my_app, ~w(--watch)]}
  ]
```

The watcher monitors:
- Per-module style data files
- The input CSS file (when configured)

### Live Reload

Watch style modules in your `live_reload` patterns:

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

## Shorthand Behaviors

Control how CSS shorthand properties are handled.

### `:accept_shorthands` (Default)

Keeps shorthands intact:

```elixir
config :live_style, shorthand_behavior: :accept_shorthands
```

```elixir
class :card,
  margin: "16px",
  margin_top: "8px"  # Overrides only top
```

### `:flatten_shorthands`

Expands to longhands:

```elixir
config :live_style, shorthand_behavior: :flatten_shorthands
```

```elixir
# margin: "16px" becomes:
# margin_top: "16px", margin_right: "16px", ...
```

### `:forbid_shorthands`

Raises compile errors for disallowed shorthands:

```elixir
config :live_style, shorthand_behavior: :forbid_shorthands
```

## CSS Layers

### Default (Specificity Hack)

Uses `:not(#\#)` selector hack for specificity:

```elixir
config :live_style, use_css_layers: false  # default
```

### CSS `@layer`

Groups rules by priority in `@layer` blocks:

```elixir
config :live_style, use_css_layers: true
```

## Vendor Prefixing

```elixir
# mix.exs
{:autoprefixer_ex, "~> 0.1"}

# config/config.exs
config :live_style, prefix_css: {AutoprefixerEx, :prefix_css}

config :autoprefixer_ex, browserslist: ["defaults"]
```

## Deprecation Warnings

```elixir
# mix.exs
{:css_compat_data_ex, "~> 0.1"}

# config/config.exs
config :live_style, deprecated?: {CSSCompatDataEx, :deprecated?}
```

```
warning: CSS property "box-align" is deprecated
  lib/my_app_web/components/button.ex:15
```

## Property Validation

LiveStyle validates CSS property names with suggestions:

```elixir
class :card, backgorund_color: "red"
# Error: Unknown CSS property "backgorund_color". Did you mean "background_color"?
```

## Test Configuration

For tests with LiveStyle modules:

```elixir
defp aliases do
  [
    test: ["live_style.setup_tests", "test"]
  ]
end
```

## All Options

### Global Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `shorthand_behavior` | atom | `:accept_shorthands` | How to handle CSS shorthands |
| `use_css_layers` | boolean | `false` | Use CSS `@layer` for specificity |
| `prefix_css` | mfa | `nil` | Vendor prefixing function |
| `deprecated?` | mfa | `nil` | Deprecation check function |

### Profile Options

| Option | Type | Description |
|--------|------|-------------|
| `input` | string | Source CSS file with `@import "live_style"` |
| `output` | string | Destination path for generated CSS |
| `cd` | string | Base directory for relative paths |
