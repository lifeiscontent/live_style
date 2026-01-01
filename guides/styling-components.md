# Styling Components

This guide covers how to define and compose styles for your Phoenix components.

## Basic Usage

Use `class/2` to define named styles:

```elixir
defmodule MyApp.Button do
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
defmodule MyApp.Card do
  use LiveStyle

  class :card,
    # Static values use const
    padding: const({MyApp.Spacing, :md}),
    border_radius: const({MyApp.Radius, :lg}),
    font_size: const({MyApp.FontSize, :base}),
    box_shadow: const({MyApp.Shadow, :md}),
    # Colors use var (for theming)
    background_color: var({MyApp.Semantic, :fill_surface}),
    color: var({MyApp.Semantic, :text_primary})
end
```

## Syntax Options

LiveStyle supports both keyword list and map syntax:

```elixir
# Keyword list syntax (recommended)
class :button,
  display: "flex",
  padding: "8px"

# Map syntax
class :button, %{
  display: "flex",
  padding: "8px"
}
```

### Computed Keys

When using `const` or module attributes as keys, use map syntax with `=>` or tuple lists:

```elixir
# Map syntax with =>
class :responsive,
  font_size: %{
    :default => const({MyApp.FontSize, :base}),
    const({MyApp.Breakpoints, :lg}) => const({MyApp.FontSize, :lg})
  }

# Tuple list syntax
class :responsive,
  font_size: [
    {:default, const({MyApp.FontSize, :base})},
    {const({MyApp.Breakpoints, :lg}), const({MyApp.FontSize, :lg})}
  ]
```

## Pseudo-classes and States

Use the StyleX pattern of condition-in-value:

```elixir
class :link,
  color: %{
    :default => var({MyApp.Semantic, :text_link}),
    ":hover" => var({MyApp.Colors, :indigo_700}),
    ":focus" => var({MyApp.Colors, :indigo_800})
  },
  text_decoration: %{
    :default => "none",
    ":hover" => "underline"
  }

class :input,
  border_color: %{
    :default => var({MyApp.Semantic, :border_default}),
    ":focus" => var({MyApp.Semantic, :border_focus}),
    ":disabled" => var({MyApp.Colors, :gray_200})
  }
```

## Media Queries

Responsive styles follow the same pattern:

```elixir
class :container,
  padding: %{
    :default => const({MyApp.Spacing, :md}),
    "@media (min-width: 768px)" => const({MyApp.Spacing, :lg}),
    "@media (min-width: 1024px)" => const({MyApp.Spacing, :xl})
  },
  max_width: %{
    :default => "100%",
    "@media (min-width: 1280px)" => "1280px"
  }
```

Using constants for breakpoints:

```elixir
class :grid,
  display: "grid",
  grid_template_columns: %{
    :default => "1fr",
    "@media #{const({MyApp.Breakpoints, :md})}" => "repeat(2, 1fr)",
    "@media #{const({MyApp.Breakpoints, :lg})}" => "repeat(3, 1fr)"
  }
```

## Pseudo-elements

```elixir
class :required_field,
  position: "relative",
  "::before": [
    content: "'*'",
    color: var({MyApp.Colors, :red_500}),
    position: "absolute",
    left: "-1em"
  ]

class :custom_checkbox,
  "::after": [
    content: "''",
    display: "block",
    width: "16px",
    height: "16px",
    background_color: %{
      :default => "transparent",
      ":checked" => var({MyApp.Semantic, :fill_primary})
    }
  ]
```

## Style Composition

### Include from Other Modules

```elixir
defmodule MyApp.BaseStyles do
  use LiveStyle

  class :button_base,
    display: "inline-flex",
    padding: const({MyApp.Spacing, :md}),
    border: "none",
    cursor: "pointer"
end

defmodule MyApp.Button do
  use LiveStyle

  class :primary, [
    include({MyApp.BaseStyles, :button_base}),
    background_color: var({MyApp.Semantic, :fill_primary}),
    color: var({MyApp.Semantic, :text_inverse})
  ]

  class :secondary, [
    include({MyApp.BaseStyles, :button_base}),
    background_color: var({MyApp.Semantic, :fill_secondary}),
    color: var({MyApp.Semantic, :text_primary})
  ]
end
```

### Self-Reference (Same Module)

```elixir
defmodule MyApp.Card do
  use LiveStyle

  class :base,
    border_radius: const({MyApp.Radius, :lg}),
    padding: const({MyApp.Spacing, :md}),
    background_color: var({MyApp.Semantic, :fill_card})

  class :elevated, [
    include(:base),
    box_shadow: const({MyApp.Shadow, :md})
  ]

  class :outlined, [
    include(:base),
    border_width: "1px",
    border_style: "solid",
    border_color: var({MyApp.Semantic, :border_default})
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
defmodule MyApp.Components do
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

Use `fallback/1` for CSS fallbacks:

```elixir
class :sticky_header,
  position: fallback(["sticky", "-webkit-sticky", "fixed"])

class :modern_layout,
  display: fallback(["grid", "flex"])
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

Access styles from other modules in templates using tuple syntax:

```heex
<button {css({MyApp.Button, :primary})}>
  Click me
</button>
```

For testing and introspection, use the Compiler module:

```elixir
# Get class string
class_string = LiveStyle.Compiler.get_css_class(MyApp.Button, :primary)

# Get LiveStyle.Attrs struct
attrs = LiveStyle.Compiler.get_css(MyApp.Button, :primary)
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

When you use `css([:base, :primary])`, LiveStyle combines the relevant atomic classes into a single class string.

## Next Steps

- [Theming](theming.md) - Create theme variations
- [Advanced Features](advanced-features.md) - Contextual selectors and view transitions
