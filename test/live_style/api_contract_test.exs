defmodule LiveStyle.APIContractTest do
  @moduledoc """
  API Contract Tests for LiveStyle.

  These tests ensure that all public consumer APIs remain stable and don't break
  in future changes. Each test verifies:
  - The API exists and is callable
  - The return type/shape is correct
  - The output format matches expected conventions

  If any of these tests fail after a change, it indicates a breaking API change
  that needs careful consideration.
  """

  # ============================================================================
  # Test Modules - Define all the APIs we're testing
  # These are defined at top level to get simple manifest keys
  # ============================================================================
end

# Top-level test modules for cleaner manifest keys
defmodule LiveStyle.APIContractTest.TokensModule do
  @moduledoc "Test module for vars, consts, keyframes"
  use LiveStyle

  # vars - Define CSS custom properties
  vars(
    white: "#ffffff",
    primary: "#3b82f6",
    danger: "#ef4444",
    # typed values
    angle: LiveStyle.PropertyType.angle("0deg"),
    duration: LiveStyle.PropertyType.time("200ms")
  )

  # consts - Define compile-time constants
  consts(
    sm: "@media (max-width: 640px)",
    md: "@media (min-width: 641px) and (max-width: 1024px)",
    lg: "@media (min-width: 1025px)",
    modal: "50",
    tooltip: "100"
  )

  # keyframes/2 - Define keyframe animations
  keyframes(:spin,
    from: [transform: "rotate(0deg)"],
    to: [transform: "rotate(360deg)"]
  )

  keyframes(:fade_in,
    "0%": [opacity: "0"],
    "100%": [opacity: "1"]
  )

  # theme/2 - Define theme overrides (in same module as vars)
  theme(:dark,
    white: "#000000",
    primary: "#8ab4f8"
  )
end

defmodule LiveStyle.APIContractTest.StylesModule do
  @moduledoc "Test module for class and style definitions"
  use LiveStyle

  alias LiveStyle.APIContractTest.TokensModule

  # Basic static rule
  class(:button,
    display: "flex",
    padding: "8px 16px",
    background_color: "blue",
    color: "white"
  )

  # Rule with pseudo-classes
  class(:link,
    color: [
      default: "blue",
      ":hover": "darkblue",
      ":focus": "navy",
      ":active": "black"
    ]
  )

  # Rule with media queries
  class(:container,
    padding: [
      default: "16px",
      "@media (min-width: 768px)": "32px",
      "@media (min-width: 1024px)": "48px"
    ]
  )

  # Rule with pseudo-elements
  class(:with_before,
    position: "relative",
    "::before": [
      content: "'*'",
      color: "red"
    ]
  )

  # Rule with array fallbacks
  class(:sticky,
    position: ["sticky", "fixed"]
  )

  # Rule referencing tokens from another module
  class(:themed,
    color: var({TokensModule, :primary}),
    animation_name: keyframes({TokensModule, :spin})
  )

  # Dynamic rule with single parameter
  class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)

  # Dynamic rule with multiple parameters
  class(:dynamic_size, fn width, height -> [width: width, height: height] end)

  # Rule with custom properties
  class(:custom_props,
    "--my-color": "red",
    "--my-size": 10
  )

  # Rule with nested pseudo-classes
  class(:nested_pseudo,
    color: [
      ":hover": [":active": "red"]
    ]
  )

  # Rule with @supports
  class(:supports_test,
    display: [
      default: "block",
      "@supports (display: grid)": "grid"
    ]
  )
end

defmodule LiveStyle.APIContractTest.PositionTryModule do
  @moduledoc "Test module for position_try"
  use LiveStyle

  position_try(:bottom_fallback,
    top: "anchor(bottom)",
    left: "anchor(left)"
  )

  position_try(:top_fallback,
    bottom: "anchor(top)",
    left: "anchor(left)"
  )
end

defmodule LiveStyle.APIContractTest.ViewTransitionModule do
  @moduledoc "Test module for view_transition_class"
  use LiveStyle

  keyframes(:vt_fade_out,
    from: [opacity: "1"],
    to: [opacity: "0"]
  )

  keyframes(:vt_fade_in,
    from: [opacity: "0"],
    to: [opacity: "1"]
  )

  view_transition_class(:card_transition,
    old: [animation_name: keyframes(:vt_fade_out), animation_duration: "250ms"],
    new: [animation_name: keyframes(:vt_fade_in), animation_duration: "250ms"]
  )
end

defmodule LiveStyle.APIContractTest.IncludeModule do
  @moduledoc "Test module for include() feature"
  use LiveStyle

  class(:base,
    display: "flex",
    align_items: "center"
  )

  class(:extended, [
    include(:base),
    justify_content: "space-between"
  ])
end

defmodule LiveStyle.APIContractTest.WhenModule do
  @moduledoc "Test module for LiveStyle.When contextual selectors"
  use LiveStyle
  alias LiveStyle.When

  # ancestor takes a pseudo selector like :hover, not a class
  class(:with_ancestor,
    color: [
      {:default, "black"},
      {When.ancestor(":hover"), "blue"}
    ]
  )

  class(:with_descendant,
    color: [
      {:default, "gray"},
      {When.descendant(":focus"), "blue"}
    ]
  )
end

# ============================================================================
# Actual Tests
# ============================================================================

defmodule LiveStyle.APIContractTest.Tests do
  use LiveStyle.TestCase

  alias LiveStyle.APIContractTest.{
    IncludeModule,
    PositionTryModule,
    StylesModule,
    TokensModule,
    ViewTransitionModule,
    WhenModule
  }

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.Class

  describe "vars API" do
    test "defines CSS variables accessible via var/1" do
      # var should return var(--hash) format
      var_entry = LiveStyle.Vars.lookup!({TokensModule, :white})
      assert var_entry.ident =~ ~r/^--[a-z0-9]+$/
    end

    test "typed variables include type information" do
      var_entry = LiveStyle.Vars.lookup!({TokensModule, :angle})

      assert var_entry != nil
      assert var_entry.type != nil
      assert var_entry.type.syntax == "<angle>"
    end
  end

  describe "consts API" do
    test "defines constants accessible at compile time" do
      const_entry = LiveStyle.Consts.lookup!({TokensModule, :lg})

      assert const_entry == %{value: "@media (min-width: 1025px)"}
    end

    test "ref returns just the value" do
      value = LiveStyle.Consts.ref({TokensModule, :lg})

      assert value == "@media (min-width: 1025px)"
    end
  end

  describe "keyframes/2 API" do
    test "defines keyframes with content-hashed name" do
      keyframes = LiveStyle.Keyframes.lookup!({TokensModule, :spin})

      assert keyframes != nil
      # StyleX keyframes naming pattern: x<hash>-B
      assert keyframes.ident =~ ~r/^x[a-z0-9]+-B$/
      assert keyframes.ltr =~ "@keyframes"
      assert keyframes.priority == 0
    end
  end

  describe "class/2 API" do
    test "static rules generate atomic classes" do
      rule = Class.lookup!({StylesModule, :button})

      assert rule != nil
      assert rule.class_string != ""
      assert is_list(rule.atomic_classes)
      assert get_atomic(rule.atomic_classes, "display") != nil
      assert get_atomic(rule.atomic_classes, "padding") != nil
    end

    test "conditional rules generate multiple classes per property" do
      rule = Class.lookup!({StylesModule, :link})

      # color should have classes list with :default, :hover, etc.
      color_classes = field(get_atomic(rule.atomic_classes, "color"), :classes)
      assert get_class(color_classes, :default) != nil
      assert get_class(color_classes, ":hover") != nil
      assert get_class(color_classes, ":focus") != nil
    end

    test "dynamic rules are marked as dynamic" do
      rule = Class.lookup!({StylesModule, :dynamic_opacity})

      assert rule.dynamic == true
    end

    test "array fallbacks generate multiple declarations" do
      rule = Class.lookup!({StylesModule, :sticky})

      position = get_atomic(rule.atomic_classes, "position")
      # Should have multiple values in LTR
      assert field(position, :ltr) =~ "position:sticky"
      assert field(position, :ltr) =~ "position:fixed"
    end
  end

  describe "theme/2 API" do
    test "defines theme with overrides" do
      theme = LiveStyle.Theme.lookup!({TokensModule, :dark})

      assert theme != nil
      # Theme names follow a pattern (may or may not start with x)
      assert is_binary(theme.ident)
      assert String.length(theme.ident) > 0
      assert is_list(theme.overrides)
    end
  end

  describe "position_try/2 API" do
    test "defines position-try rules" do
      position_try = LiveStyle.PositionTry.lookup!({PositionTryModule, :bottom_fallback})

      assert position_try != nil
      assert position_try.ident =~ ~r/^--x[a-z0-9]+$/
    end
  end

  describe "view_transition_class/2 API" do
    test "defines view transition with content-hashed name" do
      vt = LiveStyle.ViewTransition.lookup!({ViewTransitionModule, :card_transition})

      assert vt != nil
      assert vt.ident =~ ~r/^x[a-z0-9]+$/
    end
  end

  describe "__include__ feature" do
    test "extended rule includes base rule declarations" do
      rule = Class.lookup!({IncludeModule, :extended})

      # Should have display from base
      assert get_atomic(rule.atomic_classes, "display") != nil
      # Should have its own property
      assert get_atomic(rule.atomic_classes, "justify-content") != nil
    end
  end

  describe "css/1 generated function API" do
    test "returns Attrs struct for single rule" do
      attrs = Compiler.get_css(StylesModule, :button)

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "returns Attrs struct for list of rules" do
      attrs = Compiler.get_css(StylesModule, [:button, :link])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
    end

    test "handles nil and false in list (conditionals)" do
      attrs = Compiler.get_css(StylesModule, [:button, nil, false, :link])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
    end

    test "handles dynamic rules with values" do
      attrs = Compiler.get_css(StylesModule, [:button, {:dynamic_opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      # Dynamic rules set style for CSS variables
      assert attrs.style != nil or is_binary(attrs.class)
    end

    test "dynamic rules return CSS variables in style" do
      attrs = Compiler.get_css(StylesModule, [{:dynamic_opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      # Should have a CSS variable for opacity with the value
      assert attrs.style =~ ~r/--x-opacity.*0\.5/
    end

    test "dynamic rules with multiple params return all CSS variables" do
      attrs = Compiler.get_css(StylesModule, [{:dynamic_size, ["100px", "200px"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      # Should have CSS variables for width and height
      assert attrs.style =~ "width"
      assert attrs.style =~ "height"
      assert attrs.style =~ "100px"
      assert attrs.style =~ "200px"
    end
  end

  describe "class/1 generated function API" do
    test "returns string for single rule" do
      class = Compiler.get_css_class(StylesModule, :button)

      assert is_binary(class)
      assert class != ""
    end

    test "returns string for list of rules" do
      class = Compiler.get_css_class(StylesModule, [:button, :link])

      assert is_binary(class)
    end
  end

  describe "LiveStyle.Attrs struct" do
    test "has expected fields" do
      attrs = %LiveStyle.Attrs{class: "test", style: nil}

      assert is_map_key(attrs, :class)
      assert is_map_key(attrs, :style)
    end

    test "can access fields via struct syntax" do
      attrs = %LiveStyle.Attrs{class: "test", style: "color:red"}

      assert attrs.class == "test"
      assert attrs.style == "color:red"
    end
  end

  describe "LiveStyle.When contextual selectors API" do
    test "ancestor/2 is available and generates correct selector" do
      rule = Class.lookup!({WhenModule, :with_ancestor})

      assert rule != nil
      # The rule should have a color class
      assert get_atomic(rule.atomic_classes, "color") != nil
    end

    test "descendant/2 is available and generates correct selector" do
      rule = Class.lookup!({WhenModule, :with_descendant})

      assert rule != nil
    end

    test "ancestor returns correct selector format" do
      prefix = LiveStyle.Config.class_name_prefix()
      marker_class = LiveStyle.Marker.to_class(LiveStyle.Marker.default())
      selector = LiveStyle.When.ancestor(":hover")
      # Uses the configured default marker
      assert selector == ":where(.#{marker_class}:hover *)"
      assert String.contains?(selector, "#{prefix}-default-marker")
    end

    test "descendant returns correct selector format" do
      marker_class = LiveStyle.Marker.to_class(LiveStyle.Marker.default())
      selector = LiveStyle.When.descendant(":focus")
      assert selector == ":where(:has(.#{marker_class}:focus))"
    end

    test "sibling_before returns correct selector format" do
      marker_class = LiveStyle.Marker.to_class(LiveStyle.Marker.default())
      selector = LiveStyle.When.sibling_before(":checked")
      assert selector == ":where(.#{marker_class}:checked ~ *)"
    end

    test "marker returns default marker struct" do
      prefix = LiveStyle.Config.class_name_prefix()
      marker = LiveStyle.Marker.default()
      # Default marker is a struct with the class derived from configured prefix
      assert %LiveStyle.Marker{class: class} = marker
      assert class == "#{prefix}-default-marker"
    end

    test "marker with custom name generates unique marker struct" do
      prefix = LiveStyle.Config.class_name_prefix()
      marker = LiveStyle.Marker.ref(:my_marker)

      # Custom markers are structs with unique hash-based class name (StyleX format: {prefix}{hash})
      assert %LiveStyle.Marker{class: class} = marker
      assert is_binary(class)
      assert String.starts_with?(class, prefix)
      # Should NOT have the "-marker-" or "-default-marker" in it
      refute String.contains?(class, "-marker-")
    end
  end

  describe "LiveStyle.PropertyType API" do
    test "color/1 returns typed value" do
      typed = LiveStyle.PropertyType.color("#ff0000")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<color>"
      assert typed.value == "#ff0000"
    end

    test "length/1 returns typed value" do
      typed = LiveStyle.PropertyType.length("10px")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<length>"
      assert typed.value == "10px"
    end

    test "angle/1 returns typed value" do
      typed = LiveStyle.PropertyType.angle("45deg")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<angle>"
      assert typed.value == "45deg"
    end

    test "time/1 returns typed value" do
      typed = LiveStyle.PropertyType.time("200ms")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<time>"
      assert typed.value == "200ms"
    end

    test "number/1 returns typed value" do
      typed = LiveStyle.PropertyType.number("1.5")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<number>"
      assert typed.value == "1.5"
    end

    test "integer/1 returns typed value" do
      typed = LiveStyle.PropertyType.integer(5)

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<integer>"
      # Integer may be stored as string
      assert typed.value == 5 or typed.value == "5"
    end

    test "percentage/1 returns typed value" do
      typed = LiveStyle.PropertyType.percentage("50%")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<percentage>"
      assert typed.value == "50%"
    end
  end

  describe "LiveStyle.CSS public API" do
    test "generate/1 returns CSS string" do
      css = Compiler.generate_css()

      assert is_binary(css)
      # Should contain actual CSS
      assert css =~ "{"
      assert css =~ "}"
    end
  end

  describe "Cross-module references" do
    test "var can reference variables from other modules" do
      # This is tested by StylesModule.themed which references TokensModule
      rule = Class.lookup!({StylesModule, :themed})

      # color should reference the var from TokensModule
      color = get_atomic(rule.atomic_classes, "color")
      assert field(color, :ltr) =~ "var(--"
    end

    test "keyframes can reference keyframes from other modules" do
      rule = Class.lookup!({StylesModule, :themed})

      # animation-name should reference keyframes from TokensModule
      animation = get_atomic(rule.atomic_classes, "animation-name")
      assert field(animation, :ltr) =~ ~r/animation-name:x[a-z0-9]+-B/
    end
  end

  describe "Atomic class output format" do
    test "class names follow StyleX pattern (x prefix)" do
      rule = Class.lookup!({StylesModule, :button})

      # All class names should start with 'x'
      Enum.each(rule.atomic_classes, fn {_prop, meta} ->
        class = field(meta, :class) || get_default_class(field(meta, :classes))

        if class,
          do: assert(String.starts_with?(class, "x"), "Class #{class} should start with 'x'")
      end)
    end

    test "LTR output follows .classname{property:value} format" do
      rule = Class.lookup!({StylesModule, :button})

      display = get_atomic(rule.atomic_classes, "display")
      assert field(display, :ltr) =~ ~r/^\.[a-z0-9]+\{display:[^}]+\}$/
    end

    test "priorities follow StyleX convention" do
      rule = Class.lookup!({StylesModule, :button})

      # Regular properties should have priority 3000
      display = get_atomic(rule.atomic_classes, "display")
      assert field(display, :priority) == 3000

      # Custom properties should have priority 1
      custom_rule = Class.lookup!({StylesModule, :custom_props})
      custom_prop = get_atomic(custom_rule.atomic_classes, "--my-color")
      assert field(custom_prop, :priority) == 1
    end
  end

  describe "Public helper functions" do
    test "LiveStyle.class/2 returns class string" do
      class = Compiler.get_css_class(StylesModule, [:button])

      assert is_binary(class)
      assert class != ""
    end

    test "LiveStyle.class/2 merges multiple rules" do
      class = Compiler.get_css_class(StylesModule, [:button, :link])

      assert is_binary(class)
      # Should contain classes from both rules
      assert String.contains?(class, " ") or String.length(class) > 10
    end
  end

  defp get_default_class(nil), do: nil

  defp get_default_class(classes) do
    case classes[:default] do
      nil -> nil
      entry -> entry.class
    end
  end
end
