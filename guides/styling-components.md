# Styling Components

This guide covers how to define and compose styles for your Phoenix components using `LiveStyle.Sheet`.

## Basic Usage

Use `css_class/2` to define named styles:

```elixir
defmodule MyApp.Button do
  use Phoenix.Component
  use LiveStyle.Sheet

  css_class :base,
    display: "inline-flex",
    align_items: "center",
    justify_content: "center",
    padding: "8px 16px",
    border_radius: "6px",
    font_weight: "500",
    cursor: "pointer"

  css_class :primary,
    background_color: "#4f46e5",
    color: "white"

  def button(assigns) do
    ~H"""
    <button class={css_class([:base, :primary])}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

## Using Tokens

Reference tokens using `css_var` for colors/themed values and `css_const` for static values:

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_class :card,
    # Static values use css_const
    padding: css_const({MyApp.Tokens, :space, :md}),
    border_radius: css_const({MyApp.Tokens, :radius, :lg}),
    font_size: css_const({MyApp.Tokens, :font_size, :base}),
    box_shadow: css_const({MyApp.Tokens, :shadow, :md}),
    # Colors use css_var (for theming)
    background_color: css_var({MyApp.Tokens, :semantic, :fill_surface}),
    color: css_var({MyApp.Tokens, :semantic, :text_primary})
end
```

## Syntax Options

LiveStyle supports both keyword list and map syntax:

```elixir
# Keyword list syntax (recommended)
css_class :button,
  display: "flex",
  padding: "8px"

# Map syntax
css_class :button, %{
  display: "flex",
  padding: "8px"
}
```

### Computed Keys

When using `css_const` or module attributes as keys, use map syntax with `=>` or tuple lists:

```elixir
# Map syntax with =>
css_class :responsive,
  font_size: %{
    :default => css_const({MyApp.Tokens, :font_size, :base}),
    css_const({MyApp.Tokens, :breakpoint, :lg}) => css_const({MyApp.Tokens, :font_size, :lg})
  }

# Tuple list syntax
css_class :responsive,
  font_size: [
    {:default, css_const({MyApp.Tokens, :font_size, :base})},
    {css_const({MyApp.Tokens, :breakpoint, :lg}), css_const({MyApp.Tokens, :font_size, :lg})}
  ]
```

## Pseudo-classes and States

Use the StyleX pattern of condition-in-value:

```elixir
css_class :link,
  color: [
    default: css_var({MyApp.Tokens, :semantic, :text_link}),
    ":hover": css_var({MyApp.Tokens, :colors, :indigo_700}),
    ":focus": css_var({MyApp.Tokens, :colors, :indigo_800})
  ],
  text_decoration: [
    default: "none",
    ":hover": "underline"
  ]

css_class :input,
  border_color: [
    default: css_var({MyApp.Tokens, :semantic, :border_default}),
    ":focus": css_var({MyApp.Tokens, :semantic, :border_focus}),
    ":disabled": css_var({MyApp.Tokens, :colors, :gray_200})
  ]
```

## Media Queries

Responsive styles follow the same pattern:

```elixir
css_class :container,
  padding: [
    default: css_const({MyApp.Tokens, :space, :md}),
    "@media (min-width: 768px)": css_const({MyApp.Tokens, :space, :lg}),
    "@media (min-width: 1024px)": css_const({MyApp.Tokens, :space, :xl})
  ],
  max_width: [
    default: "100%",
    "@media (min-width: 1280px)": "1280px"
  ]
```

Using constants for breakpoints:

```elixir
css_class :grid,
  display: "grid",
  grid_template_columns: [
    default: "1fr",
    "@media #{css_const({MyApp.Tokens, :breakpoint, :md})}": "repeat(2, 1fr)",
    "@media #{css_const({MyApp.Tokens, :breakpoint, :lg})}": "repeat(3, 1fr)"
  ]
```

## Pseudo-elements

```elixir
css_class :required_field,
  position: "relative",
  "::before": [
    content: "'*'",
    color: css_var({MyApp.Tokens, :colors, :red_500}),
    position: "absolute",
    left: "-1em"
  ]

css_class :custom_checkbox,
  "::after": [
    content: "''",
    display: "block",
    width: "16px",
    height: "16px",
    background_color: [
      default: "transparent",
      ":checked": css_var({MyApp.Tokens, :semantic, :fill_primary})
    ]
  ]
```

## Style Composition

### Include from Other Modules

```elixir
defmodule MyApp.BaseStyles do
  use LiveStyle.Sheet

  css_class :button_base,
    display: "inline-flex",
    padding: css_const({MyApp.Tokens, :space, :md}),
    border: "none",
    cursor: "pointer"
end

defmodule MyApp.Button do
  use LiveStyle.Sheet

  css_class :primary,
    __include__: [{MyApp.BaseStyles, :button_base}],
    background_color: css_var({MyApp.Tokens, :semantic, :fill_primary}),
    color: css_var({MyApp.Tokens, :semantic, :text_inverse})

  css_class :secondary,
    __include__: [{MyApp.BaseStyles, :button_base}],
    background_color: css_var({MyApp.Tokens, :semantic, :fill_secondary}),
    color: css_var({MyApp.Tokens, :semantic, :text_primary})
end
```

### Self-Reference (Same Module)

```elixir
defmodule MyApp.Card do
  use LiveStyle.Sheet

  css_class :base,
    border_radius: css_const({MyApp.Tokens, :radius, :lg}),
    padding: css_const({MyApp.Tokens, :space, :md}),
    background_color: css_var({MyApp.Tokens, :semantic, :fill_card})

  css_class :elevated,
    __include__: [:base],
    box_shadow: css_const({MyApp.Tokens, :shadow, :md})

  css_class :outlined,
    __include__: [:base],
    border_width: "1px",
    border_style: "solid",
    border_color: css_var({MyApp.Tokens, :semantic, :border_default})
end
```

## Conditional Styles

Use Elixir's boolean logic for conditional class application:

```elixir
def button(assigns) do
  ~H"""
  <button class={css_class([
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
defmodule MyApp.Components do
  use LiveStyle.Sheet

  css_class :dynamic_opacity, fn opacity ->
    [opacity: opacity]
  end

  css_class :dynamic_color, fn r, g, b ->
    [color: "rgb(#{r}, #{g}, #{b})"]
  end

  css_class :dynamic_size, fn width, height ->
    [width: "#{width}px", height: "#{height}px"]
  end
end
```

Dynamic styles return `%LiveStyle.Attrs{}` structs. Use `css/1` to spread them:

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
- Atoms (static style names)
- `{atom, args}` tuples (dynamic styles with arguments)
- `nil` or `false` (ignored, useful for conditionals)

## Fallback Values

Use `first_that_works/1` for CSS fallbacks:

```elixir
css_class :sticky_header,
  position: first_that_works(["sticky", "-webkit-sticky", "fixed"])

css_class :modern_layout,
  display: first_that_works(["grid", "flex"])
```

This generates:

```css
.x1abc123 {
  position: fixed;
  position: -webkit-sticky;
  position: sticky;
}
```

## Cross-Module Style Access

Access styles from other modules:

```elixir
# Get class string
class = LiveStyle.get_css_class(MyApp.Button, :primary)

# Get LiveStyle.Attrs struct
attrs = LiveStyle.get_css(MyApp.Button, :primary)
```

In templates:

```heex
<button class={LiveStyle.get_css_class(MyApp.Button, :primary)}>
  Click me
</button>
```

## Generated CSS Structure

LiveStyle generates atomic CSS where each property-value pair becomes a single class:

```css
/* Each declaration is its own class */
.x1a2b3c4 { display: inline-flex }
.x5e6f7g8 { padding: 16px }
.x9h0i1j2 { border-radius: 8px }

/* Pseudo-classes get their own rules */
.x3k4l5m6:hover { background-color: #4338ca }

/* Media queries are grouped */
@media (min-width: 768px) {
  .x7n8o9p0 { padding: 24px }
}
```

When you use `css_class([:base, :primary])`, LiveStyle combines the relevant atomic classes into a single class string.

## Next Steps

- [Theming](theming.md) - Create theme variations
- [Advanced Features](advanced-features.md) - Contextual selectors and view transitions
