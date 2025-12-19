# LiveStyle

Atomic CSS-in-Elixir for Phoenix LiveView, inspired by [Meta's StyleX](https://stylexjs.com/).

LiveStyle provides a type-safe, composable styling system with:

- **Atomic CSS**: Each property-value pair becomes a single class
- **Deterministic hashing**: Same styles always produce same class names
- **CSS Variables**: Type-safe design tokens with `css_vars/2`
- **Theming**: Override variables with `css_theme/3`
- **@layer support**: CSS cascade layers for predictable specificity
- **Last-wins merging**: Like StyleX, later styles override earlier ones

## Installation

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.5.0"}
  ]
end
```

Add the LiveStyle compiler to your project:

```elixir
def project do
  [
    # ...
    compilers: Mix.compilers() ++ [:live_style]
  ]
end
```

If your tests define LiveStyle modules (e.g., test fixtures with `use LiveStyle.Sheet`),
add the test setup task to your aliases:

```elixir
defp aliases do
  [
    test: ["live_style.setup_tests", "test"]
  ]
end
```

Include the generated CSS in your root layout:

```heex
<link rel="stylesheet" href={~p"/assets/live.css"} />
```

## Configuration

LiveStyle works out of the box with sensible defaults. See `LiveStyle.Config` for all available options.

## Quick Start

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  # Define styles using keyword list syntax
  css_rule :base,
    display: "flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px"

  css_rule :primary,
    background_color: css_var({MyApp.Tokens, :fill, :primary}),
    color: "white"

  def button(assigns) do
    ~H"""
    <button class={css_class([:base, :primary])}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
```

## Module Organization

LiveStyle provides two specialized modules for clearer intent:

### `LiveStyle.Tokens` - Design Tokens

For centralized design tokens (CSS variables, keyframes, themes):

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Raw color palette (not themed)
  css_vars :colors,
    white: "#ffffff",
    black: "#000000",
    gray_900: "#111827",
    indigo_600: "#4f46e5"

  # Semantic tokens referencing colors (themed)
  css_vars :semantic,
    text_primary: css_var({:colors, :gray_900}),
    text_inverse: css_var({:colors, :white}),
    fill_primary: css_var({:colors, :indigo_600})

  # Dark theme overrides semantic tokens
  css_theme :semantic, :dark,
    text_primary: css_var({:colors, :white}),
    text_inverse: css_var({:colors, :gray_900}),
    fill_primary: css_var({:colors, :indigo_600})

  css_vars :space,
    sm: "8px",
    md: "16px",
    lg: "24px"

  css_keyframes :spin,
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
end
```

### `LiveStyle.Sheet` - Component Styles

For component-specific styles:

```elixir
defmodule MyApp.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  css_rule :base,
    display: "inline-flex",
    padding: "0.5rem 1rem",
    border_radius: "0.25rem"

  css_rule :primary,
    background_color: css_var({MyApp.Tokens, :semantic, :fill_primary}),
    color: css_var({MyApp.Tokens, :semantic, :text_inverse})

  def button(assigns) do
    ~H"""
    <button class={css_class([:base, :primary])}>
      <%= @label %>
    </button>
    """
  end
end
```

## Syntax Options

LiveStyle supports both **keyword list syntax** (recommended) and **map syntax**:

```elixir
# Keyword list syntax (recommended - more idiomatic Elixir)
css_rule :button,
  display: "flex",
  padding: "8px"

# Map syntax (also supported)
css_rule :button, %{
  display: "flex",
  padding: "8px"
}
```

**Computed keys:** When using `css_const` references or module attributes as keys, you have two options:

```elixir
# Option 1: Map syntax with =>
css_rule :responsive,
  font_size: %{
    :default => "1rem",
    css_const({MyApp.Tokens, :breakpoint, :lg}) => "1.5rem"
  }

# Option 2: Tuple list syntax (more consistent with keyword style)
css_rule :responsive,
  font_size: [
    {:default, "1rem"},
    {css_const({MyApp.Tokens, :breakpoint, :lg}), "1.5rem"}
  ]
```

Both produce identical CSS output. Use whichever style you prefer.

## Referencing Tokens

Use `css_var/1` to reference CSS variables from other modules:

```elixir
css_rule :container,
  padding: css_var({MyApp.Tokens, :space, :md}),
  background_color: css_var({MyApp.Tokens, :semantic, :fill_primary})
```

## Theming

The standard pattern for theming uses two layers:

1. **`:colors`** - Raw color palette (hex values, not themed)
2. **`:semantic`** - Semantic tokens that reference colors via `css_var` (themed)

This separation keeps color values in one place while allowing themes to swap which colors semantic tokens point to.

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Raw colors (not themed)
  css_vars :colors,
    white: "#ffffff",
    gray_900: "#111827",
    gray_50: "#f9fafb"

  # Semantic tokens reference colors (themed)
  css_vars :semantic,
    fill_page: css_var({:colors, :white}),
    fill_surface: css_var({:colors, :gray_50}),
    text_primary: css_var({:colors, :gray_900})

  # Theme overrides swap which colors semantics point to
  css_theme :semantic, :dark,
    fill_page: css_var({:colors, :gray_900}),
    fill_surface: css_var({:colors, :gray_900}),
    text_primary: css_var({:colors, :gray_50})
end
```

### Applying Themes

Use `css_theme/1` to apply a theme to a subtree:

```heex
<div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
  <!-- Children use dark theme colors -->
  <.button>I use dark colors</.button>
</div>
```

Components don't need to know about themes - they just reference semantic tokens:

```elixir
css_rule :card,
  background: css_var({MyApp.Tokens, :semantic, :fill_page}),
  color: css_var({MyApp.Tokens, :semantic, :text_primary})
```

### Multiple Themes

Define multiple themes for different contexts:

```elixir
# In your tokens module
css_theme :semantic, :dark,
  text_primary: css_var({:colors, :gray_50}),
  fill_page: css_var({:colors, :gray_900})

css_theme :semantic, :high_contrast,
  text_primary: css_var({:colors, :black}),
  fill_page: css_var({:colors, :white})
```

Themes can be nested - inner themes override outer ones:

```heex
<html class={@theme == :dark && css_theme({MyApp.Tokens, :semantic, :dark})}>
  <body>
    <!-- Uses dark or default theme based on @theme -->
  </body>
</html>
```

## Conditional Styles

Use Elixir's boolean logic for conditional styles:

```elixir
def button(assigns) do
  ~H"""
  <button class={css_class([:base, @variant == :primary && :primary, @disabled && :disabled])}>
    {render_slot(@inner_block)}
  </button>
  """
end
```

## Pseudo-classes and Media Queries

LiveStyle uses the StyleX pattern of condition-in-value:

```elixir
css_rule :link,
  color: [
    default: "blue",
    ":hover": "darkblue",
    ":focus": "navy"
  ],
  text_decoration: "none"

css_rule :container,
  padding: [
    default: "16px",
    "@media (min-width: 768px)": "32px"
  ]
```

## Pseudo-elements

```elixir
css_rule :with_before,
  position: "relative",
  "::before": [
    content: "'*'",
    color: "red",
    position: "absolute",
    left: "-1em"
  ]
```

## Style Composition

Include styles from other modules or self-reference within the same module:

```elixir
# External module include
defmodule MyApp.BaseStyles do
  use LiveStyle.Sheet

  css_rule :button_base,
    display: "inline-flex",
    padding: "8px 16px",
    cursor: "pointer"
end

defmodule MyApp.Button do
  use LiveStyle.Sheet

  css_rule :primary,
    __include__: [{MyApp.BaseStyles, :button_base}],
    background_color: css_var({MyApp.Tokens, :fill, :primary})
end

# Self-reference (same module)
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_rule :base,
    border_radius: "8px",
    padding: "16px"

  css_rule :elevated,
    __include__: [:base],
    box_shadow: "0 4px 6px rgba(0,0,0,0.1)"
end
```

## Dynamic Styles

For styles that depend on runtime values, use a function in `css_rule/2`:

```elixir
defmodule MyApp.Components do
  use LiveStyle.Sheet

  css_rule :dynamic_opacity, fn opacity ->
    [opacity: opacity]
  end

  css_rule :dynamic_color, fn r, g, b ->
    [color: "rgb(#{r}, #{g}, #{b})"]
  end
end
```

Dynamic styles return `%LiveStyle.Attrs{}` structs. Spread them in templates:

```heex
<div {css([{:dynamic_opacity, 0.5}])}>
  Faded content
</div>
```

### Merging Multiple Styles

Use `css/1` with a list to merge multiple style sources:

```heex
<div {css([
  :button,
  {:dynamic_color, [255, 0, 0]},
  {:dynamic_size, [100]},
  @is_active && :active
])}>
  Button
</div>
```

The list can contain:
- Atoms (static style names)
- `{atom, args}` tuples (dynamic styles with arguments)
- `nil` or `false` (ignored, useful for conditional styles)

## Keyframes Animations

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
end

defmodule MyApp.Spinner do
  use LiveStyle.Sheet

  css_rule :spinner,
    animation: "#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"
end
```

## Fallback Values

Use `first_that_works/1` for CSS fallbacks:

```elixir
css_rule :sticky_header,
  position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
```

## Contextual Selectors (LiveStyle.When)

Style elements based on ancestor, descendant, or sibling state - like StyleX's `stylex.when.*` API:

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet
  alias LiveStyle.When

  css_rule :card_content,
    transform: %{
      :default => "translateX(0)",
      When.ancestor(":hover") => "translateX(10px)"
    }

  def render(assigns) do
    ~H"""
    <div class={LiveStyle.default_marker()}>
      <div class={css_class(:card_content)}>
        Hover the parent to move me
      </div>
    </div>
    """
  end
end
```

> **Note:** When using computed keys like `When.ancestor(":hover")`, you must use map syntax with `=>` arrows. This is an Elixir language requirement, not a LiveStyle limitation.

### Available Selectors

| Function | Description | Generated CSS Pattern |
|----------|-------------|----------------------|
| `ancestor(pseudo)` | Style when ancestor has state | `.class:where(.marker:hover *)` |
| `descendant(pseudo)` | Style when descendant has state | `.class:where(:has(.marker:focus))` |
| `sibling_before(pseudo)` | Style when preceding sibling has state | `.class:where(.marker:hover ~ *)` |
| `sibling_after(pseudo)` | Style when following sibling has state | `.class:where(:has(~ .marker:focus))` |
| `any_sibling(pseudo)` | Style when any sibling has state | Combined selector |

### Custom Markers

Use custom markers to create independent sets of contextual selectors:

```elixir
defmodule MyApp.Table do
  use LiveStyle.Sheet
  alias LiveStyle.When

  @row_marker LiveStyle.define_marker(:row)
  @row_hover When.ancestor(":hover", @row_marker)
  @col_hover When.ancestor(":has(td:nth-of-type(2):hover)")

  css_rule :cell,
    opacity: [
      {:default, "1"},
      {When.ancestor(":hover"), "0.1"},     # Dim when container hovered
      {@row_hover, "1"},                     # Restore for hovered row
      {":hover", "1"}                        # Restore for direct hover
    ],
    background_color: [
      {:default, "transparent"},
      {@row_hover, "#2266cc77"},
      {@col_hover, "#2266cc77"},
      {":hover", "#2266cc77"}
    ]

  def render(assigns) do
    ~H"""
    <div class={LiveStyle.default_marker()}>
      <table>
        <tr class={@row_marker}>
          <td class={css_class(:cell)}>Cell</td>
        </tr>
      </table>
    </div>
    """
  end
end
```

### Nested Conditions

Combine pseudo-classes with contextual selectors for precise targeting:

```elixir
css_rule :cell,
  background_color: [
    {:default, "transparent"},
    # Only apply to nth-child(2) when column 2 is hovered
    {":nth-child(2)", %{
      :default => nil,
      When.ancestor(":has(td:nth-of-type(2):hover)") => "#2266cc77"
    }}
  ]
```

## View Transitions

LiveStyle provides first-class support for the [View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API), following StyleX's `viewTransitionClass` pattern.

### Basic Usage

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Define keyframes for your animations
  css_keyframes :scale_in,
    from: [opacity: "0", transform: "scale(0.8)"],
    to: [opacity: "1", transform: "scale(1)"]

  css_keyframes :scale_out,
    from: [opacity: "1", transform: "scale(1)"],
    to: [opacity: "0", transform: "scale(0.8)"]

  # Define view transitions
  css_view_transition :card,
    old: [
      animation_name: css_keyframes(:scale_out),
      animation_duration: "200ms",
      animation_fill_mode: "both"
    ],
    new: [
      animation_name: css_keyframes(:scale_in),
      animation_duration: "200ms",
      animation_fill_mode: "both"
    ]
end
```

### Available Pseudo-element Keys

| Key | CSS Selector |
|-----|-------------|
| `:old` | `::view-transition-old(name)` |
| `:new` | `::view-transition-new(name)` |
| `:group` | `::view-transition-group(name)` |
| `:image_pair` | `::view-transition-image-pair(name)` |
| `:old_only_child` | `::view-transition-old(name):only-child` |
| `:new_only_child` | `::view-transition-new(name):only-child` |

The `:only-child` variants apply when an element is being added or removed (not replaced), useful for different add/remove vs reorder animations.

### Respecting Reduced Motion

```elixir
css_view_transition :todo,
  old: [
    animation_name: %{
      :default => css_keyframes(:fade_out),
      "@media (prefers-reduced-motion: reduce)" => "none"
    },
    animation_duration: "200ms"
  ]
```

### JavaScript Integration

To enable View Transitions with Phoenix LiveView 1.1.18+, use the `onDocumentPatch` callback:

```javascript
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  dom: {
    onDocumentPatch(proceed) {
      if (document.startViewTransition) {
        document.startViewTransition(proceed)
      } else {
        proceed()
      }
    }
  }
})
```

For more advanced usage with transition types, see the [Phoenix LiveView View Transitions documentation](https://hexdocs.pm/phoenix_live_view/live-navigation.html#view-transitions).

### Using in Templates

Add `view-transition-name` to elements you want to animate:

```heex
<li style={"view-transition-name: #{css_view_transition({MyApp.Tokens, :todo})}-#{@id}"}>
  <%= @item.text %>
</li>
```

### Browser Support

View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+. Animations gracefully degrade in unsupported browsers.

## Typed Variables

For advanced use cases like animating gradients:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  import LiveStyle.Types

  css_vars :anim,
    rotation: angle("0deg"),
    progress: percentage("0%")

  css_vars :theme,
    accent: color("#ff0000")
end
```

This generates CSS `@property` rules that enable CSS to interpolate values.

## CSS Generation

CSS is automatically generated when you compile with the LiveStyle compiler.
You can also generate manually:

```bash
mix live_style.gen.css
```

Or specify a custom output path:

```bash
mix live_style.gen.css -o assets/css/live_style.css
```

## Development Watcher

For development, add the watcher to your Phoenix endpoint:

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    live_style: {LiveStyle.Compiler, :run, [:default, ~w(--watch)]}
  ]
```

The watcher monitors the LiveStyle manifest file and regenerates CSS whenever styles are recompiled. This requires the `file_system` dependency (included with `phoenix_live_reload`).

## Generated CSS Structure

```css
/* Typed variables generate @property rules */
@property --v1b5bwzm { syntax: "<angle>"; inherits: true; initial-value: 0deg }

/* All CSS variables in a single :root block */
:root {
  --vc1svcr: #ffffff;
  --v1co3hjg: #111827;
  --v1m8p5kx: #6366f1;
}

/* Keyframes with content-based hashes */
@keyframes x1wc8ddo-B {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Atomic classes wrapped in @layer for specificity control */
@layer live_style {
  .x1a2a7pz { outline: none }
  .xh72szh { padding: var(--vdccikb) }
  .x5u4613 { border-color: var(--vublb2l) }
}
```

## API Reference

### Token Macros (via `use LiveStyle.Tokens`)

| Macro | Description |
|-------|-------------|
| `css_vars/2` | Define CSS custom properties with a namespace |
| `css_consts/2` | Define compile-time constants (not CSS variables) |
| `css_keyframes/2` | Define keyframes animation |
| `css_theme/3` | Create theme overrides for a variable group |
| `css_position_try/2` | Define `@position-try` rules for CSS Anchor Positioning |
| `css_view_transition/2` | Define view transition styles |

### Style Macros (via `use LiveStyle.Sheet`)

| Macro | Description |
|-------|-------------|
| `css_rule/2` | Define a named style with CSS declarations |
| `first_that_works/1` | Declare fallback values for a property |

### Reference Macros (available in both)

| Macro | Description |
|-------|-------------|
| `css_var/1` | Reference a CSS variable: `css_var({Module, :namespace, :name})` |
| `css_const/1` | Reference a constant: `css_const({Module, :namespace, :name})` |
| `css_keyframes/1` | Reference keyframes: `css_keyframes({Module, :name})` |
| `css_position_try/1` | Reference position-try: `css_position_try({Module, :name})` |
| `css_view_transition/1` | Reference view transition: `css_view_transition({Module, :name})` |
| `css_theme/1` | Reference theme: `css_theme({Module, :namespace, :theme_name})` |

### Generated Functions (in modules using `LiveStyle.Sheet`)

| Function | Description |
|----------|-------------|
| `css_class/1` | Returns a class string for use with `class={...}` |
| `css/1` | Returns `%LiveStyle.Attrs{}` for spreading with `{...}` |

### Module Functions

| Function | Description |
|----------|-------------|
| `LiveStyle.default_marker/0` | Returns the default marker class for contextual selectors |
| `LiveStyle.define_marker/1` | Creates a unique marker class for custom contexts |
| `LiveStyle.css/2` | Get class string from another module: `LiveStyle.css(Module, :rule)` |
| `LiveStyle.css_class/2` | Same as `css/2` |

### Compiler Functions (via `LiveStyle.Compiler`)

| Function | Description |
|----------|-------------|
| `LiveStyle.Compiler.run/2` | Run CSS generation for a profile |
| `LiveStyle.Compiler.install_and_run/2` | Same as `run/2` (for Tailwind API compatibility) |
| `LiveStyle.Compiler.write_css/1` | Write CSS to file if changed |

### Validation Functions (via `LiveStyle.Vars`)

| Function | Description |
|----------|-------------|
| `LiveStyle.Vars.validate_references!/0` | Validate CSS variable references in manifest |

### Config Functions (via `LiveStyle.Config`)

| Function | Description |
|----------|-------------|
| `LiveStyle.Config.output_path/0` | Get configured CSS output path |
| `LiveStyle.Config.shorthand_strategy/0` | Get configured shorthand strategy |
| `LiveStyle.Config.config_for!/1` | Get configuration for a profile |

### Storage Functions (via `LiveStyle.Storage`)

| Function | Description |
|----------|-------------|
| `LiveStyle.Storage.path/0` | Get current manifest path |
| `LiveStyle.Storage.read/0` | Read manifest from file |
| `LiveStyle.Storage.write/1` | Write manifest to file |
| `LiveStyle.Storage.update/1` | Update manifest atomically |

### Contextual Selectors (via `alias LiveStyle.When`)

| Function | Description |
|----------|-------------|
| `When.ancestor/1,2` | Style when ancestor has pseudo-state |
| `When.descendant/1,2` | Style when descendant has pseudo-state |
| `When.sibling_before/1,2` | Style when preceding sibling has pseudo-state |
| `When.sibling_after/1,2` | Style when following sibling has pseudo-state |
| `When.any_sibling/1,2` | Style when any sibling has pseudo-state |

### Type Helpers (via `import LiveStyle.Types`)

| Function | Description |
|----------|-------------|
| `color/1` | CSS `<color>` type |
| `length/1` | CSS `<length>` type |
| `angle/1` | CSS `<angle>` type |
| `integer/1` | CSS `<integer>` type |
| `number/1` | CSS `<number>` type |
| `time/1` | CSS `<time>` type |
| `percentage/1` | CSS `<percentage>` type |

## Shorthand Strategies

LiveStyle supports three strategies for handling CSS shorthand properties:

```elixir
config :live_style,
  shorthand_strategy: :keep_shorthands  # default
```

### Available Strategies

| Strategy | Description |
|----------|-------------|
| `:keep_shorthands` | Pass through with null resets for cascade control (default) |
| `:expand_to_longhands` | Expand to longhand properties |
| `:reject_shorthands` | Error on disallowed shorthands |

### `:keep_shorthands` (Default)

Keeps shorthands intact and allows all shorthand properties. Uses null resets internally for cascade control. Last style wins, matching developer expectations from traditional CSS.

### `:expand_to_longhands`

Expands shorthand properties to their longhand equivalents. Produces more verbose CSS but provides maximum specificity predictability.

### `:reject_shorthands`

Certain shorthands are disallowed and raise compile-time errors. Use this mode for large codebases where you want to enforce explicit property declarations:

```elixir
# These raise compile errors in :reject_shorthands mode:
css_rule :button, border: "1px solid red"      # Use border_width, border_style, border_color
css_rule :card, background: "red url(...)"     # Use background_color, background_image
```

## CSS Anchor Positioning

LiveStyle supports [CSS Anchor Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning) through the `css_position_try/2` macro, which creates `@position-try` at-rules for fallback positioning.

```elixir
defmodule MyApp.Tooltip do
  use LiveStyle.Sheet

  css_rule :tooltip,
    position: "absolute",
    position_anchor: "--trigger",
    top: "anchor(bottom)",
    left: "anchor(center)",
    # Fallback position if tooltip doesn't fit below
    position_try_fallbacks: css_position_try(
      bottom: "anchor(top)",
      left: "anchor(center)"
    )
end
```

This generates CSS like:

```css
@position-try --x1a2b3c4 {
  bottom: anchor(top);
  left: anchor(center);
}
.x5e6f7g8 { position-try-fallbacks: --x1a2b3c4; }
```

### Allowed Properties

Only positioning-related properties are allowed in `css_position_try`:

- **Position anchor**: `position_anchor`, `position_area`
- **Inset**: `top`, `right`, `bottom`, `left`, `inset`, `inset_block`, `inset_inline`, etc.
- **Margin**: `margin`, `margin_top`, `margin_inline_start`, etc.
- **Size**: `width`, `height`, `min_width`, `max_height`, `block_size`, `inline_size`, etc.
- **Self-alignment**: `align_self`, `justify_self`, `place_self`

### Browser Support

CSS Anchor Positioning is available in Chromium 125+ (June 2024). Firefox and Safari do not yet support this feature. Consider using feature detection or providing fallback positioning for broader browser support.

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

## License

MIT License - see [LICENSE](LICENSE) for details.
