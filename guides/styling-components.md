# Styling Components

This guide covers how to define and compose styles for your Phoenix components.

## Basic Usage

Use `class/2` to define named styles:

```elixir
defmodule MyAppWeb.Button do
  use Phoenix.Component
  use LiveStyle

  class :base,
    display: "inline-flex",
    align_items: "center",
    justify_content: "center",
    padding: "8px 16px",
    border_radius: "6px",
    font_weight: "500",
    cursor: "pointer"

  class :primary,
    background_color: "#4f46e5",
    color: "white"

  def button(assigns) do
    ~H"""
    <button {css([:base, :primary])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

## Using Tokens

Reference tokens using `var` for colors/themed values and `const` for static values:

```elixir
defmodule MyAppWeb.Card do
  use LiveStyle

  class :card,
    # Static values use const
    padding: const({MyAppWeb.Spacing, :md}),
    border_radius: const({MyAppWeb.Radius, :lg}),
    font_size: const({MyAppWeb.FontSize, :base}),
    box_shadow: const({MyAppWeb.Shadow, :md}),
    # Colors use var (for theming)
    background_color: var({MyAppWeb.Semantic, :fill_surface}),
    color: var({MyAppWeb.Semantic, :text_primary})
end
```

## Pseudo-classes and States

Group conditions for a property using a list of key-value pairs:

```elixir
class :link,
  color: [
    default: var({MyAppWeb.Semantic, :text_link}),
    ":hover": var({MyAppWeb.Colors, :indigo_700}),
    ":focus": var({MyAppWeb.Colors, :indigo_800})
  ],
  text_decoration: [
    default: "none",
    ":hover": "underline"
  ]

class :input,
  border_color: [
    default: var({MyAppWeb.Semantic, :border_default}),
    ":focus": var({MyAppWeb.Semantic, :border_focus}),
    ":disabled": var({MyAppWeb.Colors, :gray_200})
  ]
```

## Media Queries

Responsive styles follow the same pattern:

```elixir
class :container,
  padding: [
    default: const({MyAppWeb.Spacing, :md}),
    "@media (min-width: 768px)": const({MyAppWeb.Spacing, :lg}),
    "@media (min-width: 1024px)": const({MyAppWeb.Spacing, :xl})
  ],
  max_width: [
    default: "100%",
    "@media (min-width: 1280px)": "1280px"
  ]
```

Using breakpoint constants with string interpolation:

```elixir
class :grid,
  display: "grid",
  grid_template_columns: [
    default: "1fr",
    "@media #{const({MyAppWeb.Breakpoints, :md})}": "repeat(2, 1fr)",
    "@media #{const({MyAppWeb.Breakpoints, :lg})}": "repeat(3, 1fr)"
  ]
```

## Pseudo-elements

```elixir
class :required_field,
  position: "relative",
  "::before": [
    content: "'*'",
    color: var({MyAppWeb.Colors, :red_500}),
    position: "absolute",
    left: "-1em"
  ]

class :custom_checkbox,
  "::after": [
    content: "''",
    display: "block",
    width: "16px",
    height: "16px",
    background_color: [
      default: "transparent",
      ":checked": var({MyAppWeb.Semantic, :fill_primary})
    ]
  ]
```

## Style Composition

### Include from Other Modules

```elixir
defmodule MyAppWeb.BaseStyles do
  use LiveStyle

  class :button_base,
    display: "inline-flex",
    padding: const({MyAppWeb.Spacing, :md}),
    border: "none",
    cursor: "pointer"
end

defmodule MyAppWeb.Button do
  use LiveStyle

  class :primary, [
    include({MyAppWeb.BaseStyles, :button_base}),
    background_color: var({MyAppWeb.Semantic, :fill_primary}),
    color: var({MyAppWeb.Semantic, :text_inverse})
  ]

  class :secondary, [
    include({MyAppWeb.BaseStyles, :button_base}),
    background_color: var({MyAppWeb.Semantic, :fill_secondary}),
    color: var({MyAppWeb.Semantic, :text_primary})
  ]
end
```

### Self-Reference (Same Module)

```elixir
defmodule MyAppWeb.Card do
  use LiveStyle

  class :base,
    border_radius: const({MyAppWeb.Radius, :lg}),
    padding: const({MyAppWeb.Spacing, :md}),
    background_color: var({MyAppWeb.Semantic, :fill_card})

  class :elevated, [
    include(:base),
    box_shadow: const({MyAppWeb.Shadow, :md})
  ]

  class :outlined, [
    include(:base),
    border_width: "1px",
    border_style: "solid",
    border_color: var({MyAppWeb.Semantic, :border_default})
  ]
end
```

## Conditional Styles

Use Elixir's boolean logic for conditional class application:

```elixir
def button(assigns) do
  ~H"""
  <button {css([
    :base,
    @variant == :primary && :primary,
    @variant == :secondary && :secondary,
    @disabled && :disabled,
    @size == :small && :small
  ])}>
    <%= render_slot(@inner_block) %>
  </button>
  """
end
```

## Dynamic Styles

For styles that depend on runtime values, use a function:

```elixir
defmodule MyAppWeb.Components do
  use LiveStyle

  class :dynamic_opacity, fn opacity ->
    [opacity: opacity]
  end

  class :dynamic_color, fn r, g, b ->
    [color: "rgb(#{r}, #{g}, #{b})"]
  end

  class :dynamic_size, fn width, height ->
    [width: "#{width}px", height: "#{height}px"]
  end
end
```

Use dynamic styles with `css/1`:

```heex
<div {css([{:dynamic_opacity, 0.5}])}>
  Faded content
</div>

<div {css([{:dynamic_color, [255, 0, 0]}])}>
  Red text
</div>
```

### Merging Static and Dynamic Styles

```heex
<div {css([
  :card,
  :elevated,
  {:dynamic_opacity, @opacity},
  @is_active && :active
])}>
  Card content
</div>
```

The list can contain:
- Atoms (static style names like `:card`)
- `{atom, args}` tuples (dynamic styles with arguments)
- Strings (pass-through CSS classes like `"my-custom-class"`)
- `nil` or `false` (ignored, useful for conditionals)

## Pass-through CSS Classes

Raw class strings are passed through unchanged, making it easy to mix LiveStyle with existing CSS or migrate incrementally from Tailwind:

```heex
<div {css([
  :card,
  "my-legacy-class",
  "another-class"
])}>
  Content
</div>
```

This outputs: `class="x1abc123 x2def456 my-legacy-class another-class"`

## Fallback Values

Use `fallback/1` for CSS fallbacks:

```elixir
class :sticky_header,
  position: fallback(["sticky", "-webkit-sticky", "fixed"])

class :modern_layout,
  display: fallback(["grid", "flex"])
```

## Cross-Module Style Access

Access styles from other modules in templates using tuple syntax:

```heex
<button {css({MyAppWeb.Button, :primary})}>
  Click me
</button>
```

## Next Steps

- [Theming](theming.md) - Create theme variations
- [Advanced Features](advanced-features.md) - Contextual selectors and view transitions
