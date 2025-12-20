# Advanced Features

This guide covers LiveStyle's advanced features: contextual selectors, view transitions, and CSS anchor positioning.

## Contextual Selectors (LiveStyle.When)

Style elements based on ancestor, descendant, or sibling state - similar to StyleX's `stylex.when.*` API.

### Basic Usage

```elixir
defmodule MyApp.Card do
  use Phoenix.Component
  use LiveStyle.Sheet
  alias LiveStyle.When

  css_class :card_content,
    transform: %{
      :default => "translateX(0)",
      When.ancestor(":hover") => "translateX(10px)"
    },
    opacity: %{
      :default => "1",
      When.ancestor(":focus-within") => "0.8"
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

> **Note:** When using computed keys like `When.ancestor(":hover")`, you must use map syntax with `=>`.

### Available Selectors

| Function | Description | Use Case |
|----------|-------------|----------|
| `ancestor(pseudo)` | Style when ancestor has state | Child reacts to parent hover |
| `descendant(pseudo)` | Style when descendant has state | Parent reacts to child focus |
| `sibling_before(pseudo)` | Style when preceding sibling has state | Next sibling reacts |
| `sibling_after(pseudo)` | Style when following sibling has state | Previous sibling reacts |
| `any_sibling(pseudo)` | Style when any sibling has state | Any sibling interaction |

### Custom Markers

Use custom markers to create independent sets of contextual selectors:

```elixir
defmodule MyApp.Table do
  use Phoenix.Component
  use LiveStyle.Sheet
  alias LiveStyle.When

  @row_marker LiveStyle.define_marker(:row)
  @row_hover When.ancestor(":hover", @row_marker)

  css_class :cell,
    opacity: [
      {:default, "1"},
      {When.ancestor(":hover"), "0.3"},  # Dim when container hovered
      {@row_hover, "1"},                  # Restore for hovered row
      {":hover", "1"}                     # Restore for direct hover
    ],
    background_color: [
      {:default, "transparent"},
      {@row_hover, "#e0e7ff"}
    ]

  def render(assigns) do
    ~H"""
    <div class={LiveStyle.default_marker()}>
      <table>
        <tr :for={row <- @rows} class={@row_marker}>
          <td :for={cell <- row} class={css_class(:cell)}>
            <%= cell %>
          </td>
        </tr>
      </table>
    </div>
    """
  end
end
```

### Nested Conditions

Combine pseudo-classes with contextual selectors:

```elixir
css_class :cell,
  background_color: [
    {:default, "transparent"},
    {":nth-child(2)", %{
      :default => nil,
      When.ancestor(":has(td:nth-of-type(2):hover)") => "#e0e7ff"
    }}
  ]
```

## View Transitions

LiveStyle provides first-class support for the [View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API).

### Defining Transitions

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  # Define keyframes
  css_keyframes :scale_in,
    from: [opacity: "0", transform: "scale(0.8)"],
    to: [opacity: "1", transform: "scale(1)"]

  css_keyframes :scale_out,
    from: [opacity: "1", transform: "scale(1)"],
    to: [opacity: "0", transform: "scale(0.8)"]

  css_keyframes :slide_from_right,
    from: [transform: "translateX(100%)"],
    to: [transform: "translateX(0)"]

  css_keyframes :slide_to_left,
    from: [transform: "translateX(0)"],
    to: [transform: "translateX(-100%)"]

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

  css_view_transition :slide,
    old: [
      animation_name: css_keyframes(:slide_to_left),
      animation_duration: "300ms"
    ],
    new: [
      animation_name: css_keyframes(:slide_from_right),
      animation_duration: "300ms"
    ]
end
```

### Available Pseudo-elements

| Key | CSS Selector | Description |
|-----|--------------|-------------|
| `:old` | `::view-transition-old(name)` | Outgoing snapshot |
| `:new` | `::view-transition-new(name)` | Incoming snapshot |
| `:group` | `::view-transition-group(name)` | Container for old/new |
| `:image_pair` | `::view-transition-image-pair(name)` | Wrapper for snapshots |
| `:old_only_child` | `::view-transition-old(name):only-child` | Element being removed |
| `:new_only_child` | `::view-transition-new(name):only-child` | Element being added |

### Respecting Reduced Motion

```elixir
css_view_transition :card,
  old: [
    animation_name: %{
      :default => css_keyframes(:scale_out),
      "@media (prefers-reduced-motion: reduce)" => "none"
    },
    animation_duration: "200ms"
  ],
  new: [
    animation_name: %{
      :default => css_keyframes(:scale_in),
      "@media (prefers-reduced-motion: reduce)" => "none"
    },
    animation_duration: "200ms"
  ]
```

### Using in Templates

Add `view-transition-name` to elements. Each element needs a unique name:

```heex
<ul>
  <li
    :for={item <- @items}
    style={"view-transition-name: #{css_view_transition({MyApp.Tokens, :card})}-#{item.id}"}
  >
    <%= item.text %>
  </li>
</ul>
```

### Phoenix LiveView Integration

Enable View Transitions with Phoenix LiveView 1.1.18+:

```javascript
// app.js
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

### Browser Support

View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+. They gracefully degrade in unsupported browsers.

## CSS Anchor Positioning

LiveStyle supports [CSS Anchor Positioning](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning) for advanced positioning scenarios like tooltips and popovers.

### Basic Usage

```elixir
defmodule MyApp.Tooltip do
  use LiveStyle.Sheet

  css_class :trigger,
    anchor_name: "--tooltip-trigger"

  css_class :tooltip,
    position: "absolute",
    position_anchor: "--tooltip-trigger",
    top: "anchor(bottom)",
    left: "anchor(center)",
    transform: "translateX(-50%)"
end
```

### Position Fallbacks

Use `css_position_try/2` for fallback positions when the preferred position doesn't fit:

```elixir
defmodule MyApp.Tokens do
  use LiveStyle.Tokens

  css_position_try :flip_to_top,
    bottom: "anchor(top)",
    left: "anchor(center)"

  css_position_try :flip_to_left,
    right: "anchor(left)",
    top: "anchor(center)"
end

defmodule MyApp.Tooltip do
  use LiveStyle.Sheet

  css_class :tooltip,
    position: "absolute",
    position_anchor: "--trigger",
    top: "anchor(bottom)",
    left: "anchor(center)",
    position_try_fallbacks: "#{css_position_try({MyApp.Tokens, :flip_to_top})}, #{css_position_try({MyApp.Tokens, :flip_to_left})}"
end
```

### Inline Position Try

For simple cases, use inline position try:

```elixir
css_class :tooltip,
  position: "absolute",
  position_anchor: "--trigger",
  top: "anchor(bottom)",
  position_try_fallbacks: css_position_try(
    bottom: "anchor(top)",
    left: "anchor(center)"
  )
```

### Allowed Properties

Only positioning-related properties are allowed in `css_position_try`:

- **Anchor**: `position_anchor`, `position_area`
- **Inset**: `top`, `right`, `bottom`, `left`, `inset`, `inset_block`, `inset_inline`
- **Margin**: `margin`, `margin_top`, `margin_right`, etc.
- **Size**: `width`, `height`, `min_width`, `max_height`, `block_size`, `inline_size`
- **Alignment**: `align_self`, `justify_self`, `place_self`

### Browser Support

CSS Anchor Positioning is available in Chromium 125+ (June 2024). Firefox and Safari don't yet support this feature. Consider feature detection or fallback positioning.

## Combining Features

These features can be combined for powerful effects:

```elixir
defmodule MyApp.Dropdown do
  use Phoenix.Component
  use LiveStyle.Sheet
  alias LiveStyle.When

  @trigger_marker LiveStyle.define_marker(:trigger)

  css_class :menu,
    position: "absolute",
    position_anchor: "--dropdown-trigger",
    top: "anchor(bottom)",
    opacity: %{
      :default => "0",
      When.sibling_before(":focus", @trigger_marker) => "1"
    },
    transform: %{
      :default => "translateY(-10px)",
      When.sibling_before(":focus", @trigger_marker) => "translateY(0)"
    },
    transition: "opacity 200ms, transform 200ms"

  def dropdown(assigns) do
    ~H"""
    <div>
      <button class={[@trigger_marker]} style="anchor-name: --dropdown-trigger">
        Menu
      </button>
      <div class={css_class(:menu)}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
```

## Next Steps

- [Configuration](configuration.md) - Shorthand behaviors and CSS layers
