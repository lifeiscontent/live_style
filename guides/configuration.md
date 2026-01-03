# Configuration

This guide covers LiveStyle's configuration options, including shorthand behaviors, CSS layers, and other settings.

## Basic Configuration

Configure LiveStyle in `config/config.exs`:

```elixir
config :live_style,
  # CSS output profile
  default: [
    output: "priv/static/assets/css/live.css",
    cd: Path.expand("..", __DIR__)
  ],

  # Optional integrations
  prefix_css: &AutoprefixerEx.prefix_css/2,
  deprecated?: &CSSCompatDataEx.deprecated?/1,

  # Behavior options
  shorthand_behavior: :accept_shorthands,
  use_css_layers: false
```

## Shorthand Behaviors

LiveStyle supports three behaviors for handling CSS shorthand properties like `margin`, `padding`, `border`, etc.

### `:accept_shorthands` (Default)

Keeps shorthands intact and allows all shorthand properties. Uses internal nil resets for cascade control:

```elixir
config :live_style,
  shorthand_behavior: :accept_shorthands
```

```elixir
# This works as expected
class :card,
  margin: "16px",
  margin_top: "8px"  # Overrides only top margin
```

This is the recommended setting for most projects. It matches how CSS naturally works - later declarations override earlier ones.

### `:flatten_shorthands`

Expands shorthand properties to their longhand equivalents:

```elixir
config :live_style,
  shorthand_behavior: :flatten_shorthands
```

```elixir
# This:
class :card, margin: "16px"

# Becomes:
class :card,
  margin_top: "16px",
  margin_right: "16px",
  margin_bottom: "16px",
  margin_left: "16px"
```

Use this mode when you need maximum predictability in how styles compose, at the cost of more verbose CSS output.

### `:forbid_shorthands`

Raises compile-time errors for certain disallowed shorthands:

```elixir
config :live_style,
  shorthand_behavior: :forbid_shorthands
```

```elixir
# These raise compile errors:
class :button, border: "1px solid red"
# Error: Use border_width, border_style, border_color instead

class :card, background: "red url(...)"
# Error: Use background_color, background_image instead
```

Use this mode for large codebases where you want to enforce explicit property declarations.

## CSS Layers

LiveStyle uses CSS specificity techniques to ensure later styles always win, regardless of declaration order.

### Default Behavior (`use_css_layers: false`)

By default, LiveStyle uses CSS specificity techniques to ensure later styles always win:

```elixir
config :live_style,
  use_css_layers: false  # default
```

### CSS Layers (`use_css_layers: true`)

Alternatively, use CSS `@layer` to control cascade precedence:

```elixir
config :live_style,
  use_css_layers: true
```

This places all LiveStyle rules in a `live_style` layer. Make sure your reset/base styles are in a lower-priority layer:

```css
/* app.css */
@layer reset, live_style;

@layer reset {
  * { box-sizing: border-box; }
}
```

## CSS Prefixing

Enable automatic vendor prefixing with `autoprefixer_ex`:

```elixir
# Add to deps
{:autoprefixer_ex, "~> 0.1.0"}

# Configure
config :live_style,
  prefix_css: &AutoprefixerEx.prefix_css/2

config :autoprefixer_ex,
  browserslist: ["defaults"]
```

LiveStyle will automatically add vendor prefixes based on your browser targets:

```elixir
# Input
class :flex, display: "flex"

# Output includes vendor prefixes like -webkit-box, -ms-flexbox, etc.
```

## Deprecation Warnings

Enable deprecation warnings with `css_compat_data_ex`:

```elixir
# Add to deps
{:css_compat_data_ex, "~> 0.1.0"}

# Configure
config :live_style,
  deprecated?: &CSSCompatDataEx.deprecated?/1
```

You'll get compile-time warnings for deprecated CSS properties:

```
warning: CSS property "box-align" is deprecated
  lib/my_app_web/components/button.ex:15
```

## CSS Validation

LiveStyle validates CSS property names at compile time with "did you mean?" suggestions:

```elixir
class :card, backgorund_color: "red"
# Error: Unknown CSS property "backgorund_color". Did you mean "background_color"?
```

## Output Profiles

Define multiple output profiles for different builds:

```elixir
config :live_style,
  default: [
    output: "priv/static/assets/css/live.css",
    cd: Path.expand("..", __DIR__)
  ],
  admin: [
    output: "priv/static/assets/css/admin.css",
    cd: Path.expand("..", __DIR__)
  ]
```

Generate CSS for a specific profile:

```bash
mix live_style admin
```

Or in aliases:

```elixir
defp aliases do
  [
    "assets.build": [
      "esbuild my_app",
      "esbuild css",
      "live_style default",
      "live_style admin"
    ]
  ]
end
```

## Development Watcher

Add the watcher to your Phoenix endpoint for automatic CSS regeneration:

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    esbuild_css: {Esbuild, :install_and_run, [:css, ~w(--watch)]},
    live_style: {LiveStyle, :install_and_run, [:default, ~w(--watch)]}
  ]
```

The watcher monitors the LiveStyle manifest and regenerates CSS when styles change. Requires the `file_system` dependency (included with `phoenix_live_reload`).

## Test Configuration

For tests that define LiveStyle modules, add the setup task:

```elixir
defp aliases do
  [
    test: ["live_style.setup_tests", "test"]
  ]
end
```

This ensures test modules are compiled and registered before tests run.

## Environment-Specific Configuration

Override settings per environment:

```elixir
# config/dev.exs
config :live_style,
  # More verbose output in dev
  shorthand_behavior: :accept_shorthands

# config/prod.exs  
config :live_style,
  # Stricter in production
  shorthand_behavior: :forbid_shorthands
```

## All Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `default` | keyword | required | Default output profile |
| `shorthand_behavior` | atom | `:accept_shorthands` | How to handle CSS shorthands |
| `use_css_layers` | boolean | `false` | Use CSS `@layer` instead of specificity hack |
| `prefix_css` | function | `nil` | Function for vendor prefixing |
| `deprecated?` | function | `nil` | Function to check property deprecation |

### Profile Options

| Option | Type | Description |
|--------|------|-------------|
| `output` | string | Path to write CSS file |
| `cd` | string | Base directory for relative paths |
