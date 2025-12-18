# LiveStyle

Atomic CSS-in-Elixir for Phoenix LiveView, inspired by [Meta's StyleX](https://stylexjs.com/).

LiveStyle provides a type-safe, composable styling system with:

- **Atomic CSS**: Each property-value pair becomes a single class
- **Deterministic hashing**: Same styles always produce same class names
- **CSS Variables**: Type-safe design tokens with `defvars/2`
- **Theming**: Override variables with `create_theme/3`
- **@layer support**: CSS cascade layers for predictable specificity
- **Last-wins merging**: Like StyleX, later styles override earlier ones

## Installation

Add `live_style` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_style, "~> 0.4.0"}
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

Include the generated CSS in your root layout:

```heex
<link rel="stylesheet" href={~p"/assets/live.css"} />
```

## Configuration

Configure LiveStyle in your `config/config.exs`:

```elixir
config :live_style,
  output_path: "priv/static/assets/live.css",
  manifest_path: "_build/live_style_manifest.etf"
```

### Options

- `:output_path` - Path where the generated CSS file is written (default: `"priv/static/assets/live.css"`)
- `:manifest_path` - Path where the compile-time manifest is stored (default: `"_build/live_style_manifest.etf"`). Useful for monorepos or custom build directories.
- `:style_resolution` - Strategy for handling shorthand CSS properties (default: `:atomic`). See [Style Resolution Modes](#style-resolution-modes) below.

## Quick Start

```elixir
defmodule MyAppWeb.Components.Button do
  use Phoenix.Component
  use LiveStyle

  # Define styles using keyword list syntax
  style :base,
    display: "flex",
    align_items: "center",
    padding: "8px 16px",
    border_radius: "8px"

  style :primary,
    background_color: var(:fill_primary),
    color: "white"

  def button(assigns) do
    ~H"""
    <button class={style([:base, :primary])}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
```

## Syntax Options

LiveStyle supports both **keyword list syntax** (recommended) and **map syntax**:

```elixir
# Keyword list syntax (recommended - more idiomatic Elixir)
style :button,
  display: "flex",
  padding: "8px"

# Map syntax (also supported)
style :button, %{
  display: "flex",
  padding: "8px"
}
```

**Computed keys:** When using function calls or module attributes as keys, you have two options:

```elixir
# Option 1: Map syntax with =>
style :responsive,
  font_size: %{
    :default => "1rem",
    Tokens.breakpoints_lg() => "1.5rem"
  }

# Option 2: Tuple list syntax (more consistent with keyword style)
style :responsive,
  font_size: [
    {:default, "1rem"},
    {Tokens.breakpoints_lg(), "1.5rem"}
  ]
```

Both produce identical CSS output. Use whichever style you prefer.

## Design Tokens

Define CSS custom properties for your design system:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  defvars :color,
    white: "#ffffff",
    black: "#000000",
    primary: "#1e68fa"

  defvars :fill,
    primary: "#3b82f6",
    secondary: "#6b7280"

  defvars :space,
    sm: "8px",
    md: "16px",
    lg: "24px"
end
```

Use tokens in your styles with the `var/1` macro:

```elixir
style :container,
  padding: var(:space_md),
  background_color: var(:fill_primary)
```

## Theming

Create theme overrides that scope to an element and its children:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  defvars :fill,
    background: "#ffffff",
    surface: "#f5f5f5"

  create_theme :dark, :fill,
    background: "#1a1a1a",
    surface: "#2d2d2d"
end
```

Apply theme in templates:

```heex
<div class={MyApp.Tokens.dark()}>
  <!-- Children use dark theme colors -->
  <.button>I use dark colors</.button>
</div>
```

## Conditional Styles

Use Elixir's boolean logic for conditional styles:

```elixir
def button(assigns) do
  ~H"""
  <button class={style([:base, @variant == :primary && :primary, @disabled && :disabled])}>
    {render_slot(@inner_block)}
  </button>
  """
end
```

## Pseudo-classes and Media Queries

LiveStyle uses the StyleX pattern of condition-in-value:

```elixir
style :link,
  color: [
    default: "blue",
    ":hover": "darkblue",
    ":focus": "navy"
  ],
  text_decoration: "none"

style :container,
  padding: [
    default: "16px",
    "@media (min-width: 768px)": "32px"
  ]
```

## Pseudo-elements

```elixir
style :with_before,
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
  use LiveStyle

  style :button_base,
    display: "inline-flex",
    padding: "8px 16px",
    cursor: "pointer"
end

defmodule MyApp.Button do
  use LiveStyle

  style :primary,
    __include__: [{MyApp.BaseStyles, :button_base}],
    background_color: var(:fill_primary)
end

# Self-reference (same module)
defmodule MyApp.Card do
  use LiveStyle

  style :base,
    border_radius: "8px",
    padding: "16px"

  style :elevated,
    __include__: [:base],
    box_shadow: "0 4px 6px rgba(0,0,0,0.1)"
end
```

## Dynamic Styles

For styles that depend on runtime values, use a function in `style/2`:

```elixir
defmodule MyApp.Components do
  use LiveStyle

  style :dynamic_opacity, fn opacity ->
    [opacity: opacity]
  end

  style :dynamic_color, fn r, g, b ->
    [color: "rgb(#{r}, #{g}, #{b})"]
  end
end
```

Dynamic styles return `{class, style_map}` tuples. Use `props/1` to convert them for templates:

```heex
<div {LiveStyle.props(MyApp.Components.dynamic_opacity(0.5))}>
  Faded content
</div>
```

### Merging Multiple Styles

Use `props/1` with a list to merge multiple style sources:

```heex
<div {LiveStyle.props([
  MyStyles.button(),
  MyStyles.dynamic_color(255, 0, 0),
  MyStyles.dynamic_size(100),
  @is_active && MyStyles.active()
])}>
  Button
</div>
```

The list can contain:
- Class strings (from static styles)
- `{class, style}` tuples (from dynamic styles)
- `nil` or `false` (ignored, useful for conditional styles)

## Keyframes Animations

```elixir
defmodule MyApp.Animations do
  use LiveStyle

  # keyframes/1 returns the generated animation name
  @spin keyframes(
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
  )

  style :spinner,
    animation_name: @spin,
    animation_duration: "1s",
    animation_iteration_count: "infinite"

  # Or inline directly
  style :pulse,
    animation_name: keyframes(
      "0%": [opacity: "1"],
      "50%": [opacity: "0.5"],
      "100%": [opacity: "1"]
    ),
    animation_duration: "2s"
end
```

## Fallback Values

Use `first_that_works/1` for CSS fallbacks:

```elixir
style :sticky_header,
  position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
```

## Contextual Selectors (LiveStyle.When)

Style elements based on ancestor, descendant, or sibling state - like StyleX's `stylex.when.*` API:

```elixir
defmodule MyApp.Card do
  use LiveStyle
  import LiveStyle.When

  style :card_content,
    transform: %{
      :default => "translateX(0)",
      ancestor(":hover") => "translateX(10px)"
    }

  def render(assigns) do
    ~H"""
    <div class={LiveStyle.default_marker()}>
      <div class={style(:card_content)}>
        Hover the parent to move me
      </div>
    </div>
    """
  end
end
```

> **Note:** When using computed keys like `ancestor(":hover")`, you must use map syntax with `=>` arrows. This is an Elixir language requirement, not a LiveStyle limitation.

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
  use LiveStyle
  import LiveStyle.When

  @row_marker LiveStyle.define_marker(:row)
  @row_hover ancestor(":hover", @row_marker)
  @col_hover ancestor(":has(td:nth-of-type(2):hover)")

  style :cell,
    opacity: conditions([
      {:default, "1"},
      {ancestor(":hover"), "0.1"},     # Dim when container hovered
      {@row_hover, "1"},                # Restore for hovered row
      {":hover", "1"}                   # Restore for direct hover
    ]),
    background_color: conditions([
      {:default, "transparent"},
      {@row_hover, "#2266cc77"},
      {@col_hover, "#2266cc77"},
      {":hover", "#2266cc77"}
    ])

  def render(assigns) do
    ~H"""
    <div class={LiveStyle.default_marker()}>
      <table>
        <tr class={@row_marker}>
          <td class={style(:cell)}>Cell</td>
        </tr>
      </table>
    </div>
    """
  end
end
```

### The `conditions/1` Helper

Use `conditions/1` when you need module attributes as condition keys:

```elixir
@row_hover ancestor(":hover", @row_marker)

style :cell,
  opacity: conditions([
    {:default, "1"},
    {@row_hover, "0.5"},  # Module attribute as key
    {":hover", "1"}
  ])
```

### Nested Conditions

Combine pseudo-classes with contextual selectors for precise targeting:

```elixir
style :cell,
  background_color: conditions([
    {:default, "transparent"},
    # Only apply to nth-child(2) when column 2 is hovered
    {":nth-child(2)", %{
      :default => nil,
      ancestor(":has(td:nth-of-type(2):hover)") => "#2266cc77"
    }}
  ])
```

## View Transitions

LiveStyle provides first-class support for the [View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API), following StyleX's `viewTransitionClass` pattern.

### Basic Usage

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  use LiveStyle.ViewTransitions

  # Define keyframes for your animations
  defkeyframes :scale_in,
    from: [opacity: "0", transform: "scale(0.8)"],
    to: [opacity: "1", transform: "scale(1)"]

  defkeyframes :scale_out,
    from: [opacity: "1", transform: "scale(1)"],
    to: [opacity: "0", transform: "scale(0.8)"]

  # Define view transitions using atom keys
  # Keyframe atoms are automatically resolved to their hashed names
  view_transition "card-*",
    old: [
      animation_name: :scale_out,
      animation_duration: "200ms",
      animation_fill_mode: "both"
    ],
    new: [
      animation_name: :scale_in,
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

### Compile-time Validation

LiveStyle validates keyframe references at compile time. If you reference an undefined keyframe, you'll get a helpful error:

```elixir
view_transition "item-*",
  old: [animation_name: :nonexistent_keyframe]

# => ** (CompileError) Undefined keyframe reference(s): :nonexistent_keyframe
#    Defined keyframes: :fade_in, :fade_out
```

CSS keywords like `:none`, `:inherit`, `:initial`, and `:unset` are allowed without being defined as keyframes.

### Respecting Reduced Motion

```elixir
view_transition "todo-*",
  old: [
    animation_name: %{
      :default => :fade_out,
      "@media (prefers-reduced-motion: reduce)" => "none"
    },
    animation_duration: "200ms"
  ]
```

### JavaScript Integration

To enable View Transitions with Phoenix LiveView, add to your `app.js`:

```javascript
if (document.startViewTransition) {
  const originalRequestDOMUpdate = liveSocket.requestDOMUpdate.bind(liveSocket)
  liveSocket.requestDOMUpdate = (callback) => {
    document.startViewTransition(() => originalRequestDOMUpdate(callback))
  }
}
```

### Using in Templates

Add `view-transition-name` to elements you want to animate:

```heex
<li style={"view-transition-name: todo-#{@id}"}>
  <%= @item.text %>
</li>
```

The wildcard pattern `todo-*` in `view_transition/2` matches all elements with names like `todo-1`, `todo-2`, etc.

### Browser Support

View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+. Animations gracefully degrade in unsupported browsers.

## Typed Variables

For advanced use cases like animating gradients:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens
  import LiveStyle.Types

  defvars :anim,
    rotation: angle("0deg"),
    progress: percentage("0%")

  defvars :theme,
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
    live_style: {LiveStyle.Watcher, :watch, [[]]}
  ]
```

The watcher monitors the LiveStyle manifest file and regenerates CSS whenever styles are recompiled. This requires the `file_system` dependency (included with `phoenix_live_reload`).

## Generated CSS Structure

```css
@property --v1234567 {
  syntax: '<color>';
  inherits: true;
  initial-value: #ff0000;
}

:root {
  --v1234567: #ff0000;
  --v2345678: 16px;
}

@keyframes k1234567 {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

@layer live_style {
  .x1a2b3c4 { display: flex; }
  .x2b3c4d5 { padding: var(--v2345678); }
  .x3c4d5e6 { background-color: var(--v1234567); }
}
```

## API Reference

### Core Macros (via `use LiveStyle`)

| Macro | Description |
|-------|-------------|
| `style/2` | Define a named style with CSS declarations |
| `keyframes/1` | Create keyframes animation and return the generated name |
| `var/1` | Reference a CSS custom property |
| `first_that_works/1` | Declare fallback values for a property |
| `conditions/1` | Build conditional value map from tuples (for module attrs as keys) |
| `position_try/1` | Create `@position-try` rules for CSS Anchor Positioning |

### Marker Functions

| Function | Description |
|----------|-------------|
| `LiveStyle.default_marker/0` | Returns the default marker class (`"{prefix}-default-marker"`) |
| `LiveStyle.define_marker/1` | Creates a unique marker class for custom contexts |

### Contextual Selectors (via `import LiveStyle.When`)

| Function | Description |
|----------|-------------|
| `ancestor/1,2` | Style when ancestor has pseudo-state |
| `descendant/1,2` | Style when descendant has pseudo-state |
| `sibling_before/1,2` | Style when preceding sibling has pseudo-state |
| `sibling_after/1,2` | Style when following sibling has pseudo-state |
| `any_sibling/1,2` | Style when any sibling has pseudo-state |

### Token Macros (via `use LiveStyle.Tokens`)

| Macro | Description |
|-------|-------------|
| `defvars/2` | Define CSS custom properties with a namespace |
| `defconsts/2` | Define compile-time constants (not CSS variables) |
| `defkeyframes/2` | Define keyframes and create a function returning the hashed name |
| `keyframes/1` | Create keyframes and return the generated name |
| `create_theme/3` | Create theme overrides for a var group |
| `position_try/1` | Create `@position-try` rules for CSS Anchor Positioning |

### View Transitions (via `use LiveStyle.ViewTransitions`)

| Macro | Description |
|-------|-------------|
| `view_transition/2` | Define view transition styles for a name pattern |
| `view_transition_class/1` | Create view transition styles and return the generated class name |

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

### Module Functions

| Function | Description |
|----------|-------------|
| `LiveStyle.props/1` | Merge style references into `[class: "...", style: "..."]` for templates |
| `LiveStyle.inline_style/1` | Convert a style map to a CSS style string |
| `LiveStyle.get_all_css/0` | Get complete CSS output |
| `LiveStyle.write_css/1` | Write CSS to file if changed (used by compiler/watcher) |
| `LiveStyle.clear/0` | Clear all collected CSS (useful for testing) |
| `LiveStyle.output_path/0` | Get configured CSS output path |
| `LiveStyle.manifest_path/0` | Get configured manifest path |
| `LiveStyle.style_resolution/0` | Get configured style resolution mode |

## Style Resolution Modes

LiveStyle supports three strategies for handling CSS shorthand properties:

```elixir
config :live_style,
  style_resolution: :atomic  # default
```

### Available Modes

| Mode | Description | CSS Output for `margin: "10px 20px"` |
|------|-------------|--------------------------------------|
| `:atomic` | Pass through with null resets for cascade control | `margin: 10px 20px` |
| `:strict` | Pass through as-is, error on disallowed shorthands | `margin: 10px 20px` |
| `:expanded` | Expand to longhand properties | `margin-top: 10px; margin-right: 20px; ...` |

### `:atomic` (Default)

Keeps shorthands intact and allows all shorthand properties. Uses null resets internally for cascade control. Last style wins, matching developer expectations from traditional CSS. Good for maximum CSS compatibility and intuitive behavior.

### `:strict`

Shorthands like `margin`, `padding`, `gap` pass through unchanged. Certain shorthands are disallowed and raise compile-time errors. Use this mode for large codebases where you want to enforce explicit property declarations:

```elixir
# These raise compile errors in :strict mode:
style :button, border: "1px solid red"      # Use border_width, border_style, border_color
style :card, background: "red url(...)"     # Use background_color, background_image
style :animated, animation: "fade 1s"       # Use animation_name, animation_duration
```

### `:expanded`

Expands shorthand properties to their longhand equivalents. Produces more verbose CSS but provides maximum specificity predictability when mixing shorthands and longhands.

## CSS Anchor Positioning

LiveStyle supports [CSS Anchor Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning) through the `position_try/1` macro, which creates `@position-try` at-rules for fallback positioning.

```elixir
defmodule MyApp.Tooltip do
  use LiveStyle

  style :tooltip,
    position: "absolute",
    position_anchor: "--trigger",
    top: "anchor(bottom)",
    left: "anchor(center)",
    # Fallback position if tooltip doesn't fit below
    position_try_fallbacks: position_try(
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

Only positioning-related properties are allowed in `position_try`:

- **Position anchor**: `position_anchor`, `position_area`
- **Inset**: `top`, `right`, `bottom`, `left`, `inset`, `inset_block`, `inset_inline`, etc.
- **Margin**: `margin`, `margin_top`, `margin_inline_start`, etc.
- **Size**: `width`, `height`, `min_width`, `max_height`, `block_size`, `inline_size`, etc.
- **Self-alignment**: `align_self`, `justify_self`, `place_self`

### Sharing Position Fallbacks

To share position-try values across modules, use `defvars`:

```elixir
defmodule MyApp.PositionFallbacks do
  use LiveStyle.Tokens

  defvars :fallback,
    top_left: position_try(top: "0", left: "0", width: "100px"),
    bottom_right: position_try(bottom: "0", right: "0", width: "100px")
end
```

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
