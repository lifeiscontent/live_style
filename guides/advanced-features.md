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

### Phoenix LiveView Integration

View Transitions require JavaScript integration to work with Phoenix LiveView. The key insight is that `view-transition-name` must be applied **before** `startViewTransition()` captures the old state snapshot.

#### Step 1: Create the View Transitions Adapter

Create `assets/js/view-transitions.js`:

```javascript
/**
 * Phoenix LiveView View Transitions Adapter
 * 
 * Integrates the CSS View Transitions API with Phoenix LiveView.
 * Works with LiveView 1.1.18+ which provides the `onDocumentPatch` DOM callback.
 */

// Global state for hooks
window.__viewTransitionPending = false
window.__vtCounter = 0

export function createViewTransitionDom(options = {}) {
  const existingDom = options.dom || {}
  let transitionTypes = []

  // Listen for view transition events from LiveView
  window.addEventListener("phx:start-view-transition", (e) => {
    const opts = e.detail || {}
    if (opts.types && Array.isArray(opts.types)) {
      transitionTypes.push(...opts.types)
    }
    window.__viewTransitionPending = true
  })

  return {
    ...existingDom,
    
    onDocumentPatch(start) {
      const existingOnDocumentPatch = existingDom.onDocumentPatch
      
      const update = () => {
        const types = transitionTypes
        transitionTypes = []
        
        if (existingOnDocumentPatch) {
          existingOnDocumentPatch(start)
        } else {
          start()
        }
        
        window.__viewTransitionPending = false
      }

      // Only use View Transitions if scheduled
      if (!window.__viewTransitionPending || !document.startViewTransition) {
        update()
        return
      }

      // Start the view transition
      try {
        document.startViewTransition({
          update,
          types: transitionTypes.length ? transitionTypes : ["same-document"],
        })
      } catch (error) {
        // Firefox 144+ doesn't support callbackOptions yet
        document.startViewTransition(update)
      }
    },

    onBeforeElUpdated(fromEl, toEl) {
      if (existingDom.onBeforeElUpdated) {
        return existingDom.onBeforeElUpdated(fromEl, toEl)
      }
      return true
    }
  }
}

export default createViewTransitionDom
```

#### Step 2: Configure LiveSocket

In your `assets/js/app.js`:

```javascript
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { createViewTransitionDom } from "./view-transitions"

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  dom: createViewTransitionDom()
})
```

#### Step 3: Create a ViewTransition Component

Create a reusable component that manages `view-transition-name` via a hook:

```elixir
defmodule MyAppWeb.ViewTransition do
  use Phoenix.Component

  @doc """
  Renders the hook definition. Include once in your root layout.
  """
  def hook_definition(assigns) do
    assigns = assign_new(assigns, :id, fn -> "view-transition-hook-def" end)

    ~H"""
    <div id={@id} style="display:none;">
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ViewTransition">
        export default {
          mounted() {
            // Generate unique name if not provided
            if (!this.el.__vtName) {
              this.el.__vtName = this.el.dataset.viewTransitionName || `_vt_${window.__vtCounter++}_`;
            }
            // Apply immediately so transitions work on first interaction
            this.el.style.viewTransitionName = this.el.__vtName;
            if (this.el.dataset.viewTransitionClass) {
              this.el.style.viewTransitionClass = this.el.dataset.viewTransitionClass;
            }
          },

          updated() {
            // Keep name applied (morphdom may remove it)
            this.el.style.viewTransitionName = this.el.__vtName;
            if (this.el.dataset.viewTransitionClass) {
              this.el.style.viewTransitionClass = this.el.dataset.viewTransitionClass;
            }
          }
        }
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :"view-transition-name", :string, default: nil
  attr :"view-transition-class", :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @doc """
  Renders a view transition wrapper.
  
  Apply styles directly to the wrapper - don't use `display: contents`
  as it breaks view transition snapshots.
  """
  def view_transition(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook=".ViewTransition"
      data-view-transition-name={assigns[:"view-transition-name"]}
      data-view-transition-class={assigns[:"view-transition-class"]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
```

#### Step 4: Use in Your LiveView

First, include the hook definition once in your root layout:

```heex
<!-- In root.html.heex -->
<MyAppWeb.ViewTransition.hook_definition />
```

Then use the component in your LiveViews:

```elixir
defmodule MyAppWeb.TodoLive do
  use MyAppWeb, :live_view
  import MyAppWeb.ViewTransition

  # Define your transition styles
  css_view_transition :todo_item,
    group: [
      animation_duration: ".3s",
      animation_timing_function: "ease-out"
    ]

  def render(assigns) do
    ~H"""
    <ul>
      <.view_transition
        :for={todo <- @todos}
        id={"todo-#{todo.id}"}
        class={css_class(:todo_item)}
        view-transition-class={css_view_transition(:todo_item)}
      >
        <%= todo.text %>
      </.view_transition>
    </ul>
    """
  end
end
```

#### Step 5: Trigger Transitions from LiveView

Push a `start-view-transition` event before DOM updates:

```elixir
def handle_event("shuffle", _params, socket) do
  {:noreply,
   socket
   |> assign(items: Enum.shuffle(socket.assigns.items))
   |> push_event("start-view-transition", %{types: ["shuffle"]})}
end
```

### Key Insights

1. **Apply names on mount**: The `view-transition-name` must be set **before** `startViewTransition()` captures the old state. The hook applies it immediately in `mounted()`.

2. **Don't use `display: contents`**: It removes the element from the box tree and breaks view transition snapshots. Apply styles directly to the wrapper.

3. **Use `:only-child` for enter/exit**: When elements are added or removed, use `::view-transition-new(name):only-child` for enter animations and `::view-transition-old(name):only-child` for exit animations.

4. **Avoid animations when unchanged**: If you define custom `old`/`new` animations, they play even when elements don't change. Use `:group` for duration/easing on elements that move, and reserve `old`/`new` for actual enter/exit animations.

### Browser Support

View Transitions are supported in Chrome 111+, Edge 111+, Safari 18+, and Firefox 144+. They gracefully degrade in unsupported browsers.

## Scroll-Driven Animations

LiveStyle supports [Scroll-Driven Animations](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_scroll-driven_animations) - CSS animations that progress based on scroll position rather than time.

### Scroll Progress Timeline

Animate based on scroll position of the document or a scrollable container:

```elixir
defmodule MyApp.ScrollProgress do
  use LiveStyle.Sheet

  # Keyframes for the progress bar
  css_keyframes :grow_progress,
    from: %{transform: "scaleX(0)"},
    to: %{transform: "scaleX(1)"}

  # Reading progress bar at top of page
  css_class :progress_bar,
    position: "fixed",
    top: "0",
    left: "0",
    width: "100%",
    height: "4px",
    background: "linear-gradient(90deg, #4f46e5, #7c3aed)",
    transform_origin: "left",
    # Scroll-driven animation
    animation_name: css_keyframes(:grow_progress),
    animation_timeline: "scroll()",
    animation_timing_function: "linear"
end
```

The `scroll()` function creates an anonymous scroll progress timeline that tracks the nearest scrollable ancestor (or the document).

### View Progress Timeline

Animate based on an element's visibility within the viewport:

```elixir
defmodule MyApp.RevealOnScroll do
  use LiveStyle.Sheet

  css_keyframes :reveal,
    from: %{opacity: "0", transform: "translateY(50px)"},
    to: %{opacity: "1", transform: "translateY(0)"}

  css_class :reveal_card,
    animation_name: css_keyframes(:reveal),
    animation_timeline: "view()",
    animation_range: "entry 0% cover 40%",
    animation_fill_mode: "both"
end
```

The `view()` function tracks when the element enters and exits the viewport.

### Named View Timelines for Parallax

For parallax effects where a child animates based on its parent's visibility, use named view timelines:

```elixir
defmodule MyApp.Parallax do
  use LiveStyle.Sheet

  # Parallax animation - shifts background position as container scrolls
  css_keyframes :parallax_shift,
    from: %{background_position: "center 100%"},
    to: %{background_position: "center 0%"}

  # Container defines the named view timeline
  css_class :parallax_container,
    position: "relative",
    height: "400px",
    overflow: "hidden",
    # Define a named view timeline on the container
    view_timeline_name: "--parallax-container",
    view_timeline_axis: "block"

  # Child references the named timeline
  css_class :parallax_bg,
    position: "absolute",
    inset: "0",
    # Gradient taller than container for parallax movement
    background: "linear-gradient(135deg, #667eea 0%, #764ba2 50%, #667eea 100%)",
    background_size: "100% 200%",
    animation_name: css_keyframes(:parallax_shift),
    # Reference the container's timeline (not view())
    animation_timeline: "--parallax-container",
    animation_fill_mode: "both",
    animation_duration: "1ms"
end
```

**Why use named timelines for parallax?**

The `view()` function tracks when the **animated element itself** enters the viewport. For absolutely positioned children inside a container with `overflow: hidden`, the browser can't properly track the child's visibility. By defining the timeline on the container and referencing it from the child, the animation is driven by the container's visibility instead.

### Horizontal Scroll Timeline

Track horizontal scroll progress with named scroll timelines:

```elixir
defmodule MyApp.HorizontalScroll do
  use LiveStyle.Sheet

  css_keyframes :grow_progress,
    from: %{transform: "scaleX(0)"},
    to: %{transform: "scaleX(1)"}

  css_class :horizontal_scroll_wrapper,
    overflow_x: "auto",
    # Define a named scroll timeline for horizontal axis
    scroll_timeline_name: "--horizontal-scroll",
    scroll_timeline_axis: "x"

  css_class :horizontal_progress_bar,
    width: "100%",
    height: "4px",
    background: "linear-gradient(90deg, #10b981, #059669)",
    transform_origin: "left",
    # Reference the named scroll timeline
    animation_name: css_keyframes(:grow_progress),
    animation_timeline: "--horizontal-scroll",
    animation_timing_function: "linear",
    animation_duration: "1ms"
end
```

### Animation Range

Control when the animation starts and ends with `animation_range`:

```elixir
# Start at 0% of entry, end at 40% of cover
animation_range: "entry 0% cover 40%"

# Full range from entry to exit
animation_range: "entry exit"

# Start when 25% visible, end when 75% visible  
animation_range: "cover 25% cover 75%"
```

Range keywords:
- `entry` - Element entering the viewport
- `exit` - Element exiting the viewport
- `cover` - Element covering the viewport
- `contain` - Element contained within viewport

### Browser Support

Scroll-driven animations are supported in Chrome 115+, Edge 115+, and Safari 18+. They require no JavaScript - the browser handles all animation timing based on scroll position.

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
