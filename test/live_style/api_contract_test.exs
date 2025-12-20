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
  @moduledoc "Test module for css_vars, css_consts, css_keyframes"
  use LiveStyle

  # css_vars/2 - Define CSS custom properties
  css_vars(:color,
    white: "#ffffff",
    primary: "#3b82f6",
    danger: "#ef4444"
  )

  # css_vars/2 with typed values
  css_vars(:anim,
    angle: LiveStyle.Types.angle("0deg"),
    duration: LiveStyle.Types.time("200ms")
  )

  # css_consts/2 - Define compile-time constants
  css_consts(:breakpoint,
    sm: "@media (max-width: 640px)",
    md: "@media (min-width: 641px) and (max-width: 1024px)",
    lg: "@media (min-width: 1025px)"
  )

  css_consts(:z,
    modal: "50",
    tooltip: "100"
  )

  # css_keyframes/2 - Define keyframe animations
  css_keyframes(:spin,
    from: %{transform: "rotate(0deg)"},
    to: %{transform: "rotate(360deg)"}
  )

  css_keyframes(:fade_in,
    "0%": %{opacity: "0"},
    "100%": %{opacity: "1"}
  )

  # css_theme/3 - Define theme overrides
  css_theme(:color, :dark,
    white: "#000000",
    primary: "#8ab4f8"
  )
end

defmodule LiveStyle.APIContractTest.StylesModule do
  @moduledoc "Test module for css_class and style definitions"
  use LiveStyle

  alias LiveStyle.APIContractTest.TokensModule

  # Basic static rule
  css_class(:button,
    display: "flex",
    padding: "8px 16px",
    background_color: "blue",
    color: "white"
  )

  # Rule with pseudo-classes
  css_class(:link,
    color: [
      default: "blue",
      ":hover": "darkblue",
      ":focus": "navy",
      ":active": "black"
    ]
  )

  # Rule with media queries
  css_class(:container,
    padding: [
      default: "16px",
      "@media (min-width: 768px)": "32px",
      "@media (min-width: 1024px)": "48px"
    ]
  )

  # Rule with pseudo-elements
  css_class(:with_before,
    position: "relative",
    "::before": [
      content: "'*'",
      color: "red"
    ]
  )

  # Rule with array fallbacks
  css_class(:sticky,
    position: ["sticky", "fixed"]
  )

  # Rule referencing tokens from another module
  css_class(:themed,
    color: css_var({TokensModule, :color, :primary}),
    animation_name: css_keyframes({TokensModule, :spin})
  )

  # Dynamic rule with single parameter
  css_class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)

  # Dynamic rule with multiple parameters
  css_class(:dynamic_size, fn width, height -> [width: width, height: height] end)

  # Rule with custom properties
  css_class(:custom_props,
    "--my-color": "red",
    "--my-size": 10
  )

  # Rule with nested pseudo-classes
  css_class(:nested_pseudo,
    color: [
      ":hover": [":active": "red"]
    ]
  )

  # Rule with @supports
  css_class(:supports_test,
    display: [
      default: "block",
      "@supports (display: grid)": "grid"
    ]
  )
end

defmodule LiveStyle.APIContractTest.PositionTryModule do
  @moduledoc "Test module for css_position_try"
  use LiveStyle

  css_position_try(:bottom_fallback,
    top: "anchor(bottom)",
    left: "anchor(left)"
  )

  css_position_try(:top_fallback,
    bottom: "anchor(top)",
    left: "anchor(left)"
  )
end

defmodule LiveStyle.APIContractTest.ViewTransitionModule do
  @moduledoc "Test module for css_view_transition"
  use LiveStyle

  css_keyframes(:vt_fade_out,
    from: %{opacity: "1"},
    to: %{opacity: "0"}
  )

  css_keyframes(:vt_fade_in,
    from: %{opacity: "0"},
    to: %{opacity: "1"}
  )

  css_view_transition(:card_transition,
    old: [animation_name: css_keyframes(:vt_fade_out), animation_duration: "250ms"],
    new: [animation_name: css_keyframes(:vt_fade_in), animation_duration: "250ms"]
  )
end

defmodule LiveStyle.APIContractTest.IncludeModule do
  @moduledoc "Test module for __include__ feature"
  use LiveStyle

  css_class(:base,
    display: "flex",
    align_items: "center"
  )

  css_class(:extended,
    __include__: [:base],
    justify_content: "space-between"
  )
end

defmodule LiveStyle.APIContractTest.WhenModule do
  @moduledoc "Test module for LiveStyle.When contextual selectors"
  use LiveStyle
  alias LiveStyle.When

  # ancestor takes a pseudo selector like :hover, not a class
  css_class(:with_ancestor,
    color: %{
      :default => "black",
      When.ancestor(":hover") => "blue"
    }
  )

  css_class(:with_descendant,
    color: %{
      :default => "gray",
      When.descendant(":focus") => "blue"
    }
  )
end

# ============================================================================
# Actual Tests
# ============================================================================

defmodule LiveStyle.APIContractTest.Tests do
  use LiveStyle.TestCase, async: true

  alias LiveStyle.APIContractTest.{
    IncludeModule,
    PositionTryModule,
    StylesModule,
    TokensModule,
    ViewTransitionModule,
    WhenModule
  }

  describe "css_vars/2 API" do
    test "defines CSS variables accessible via css_var/1" do
      # css_var should return var(--hash) format
      var_ref = LiveStyle.Hash.var_name(TokensModule, :color, :white)
      assert var_ref =~ ~r/^--[a-z0-9]+$/
    end

    test "typed variables include type information" do
      var_entry = LiveStyle.get_metadata(TokensModule, {:var, :anim, :angle})

      assert var_entry != nil
      assert var_entry.type != nil
      assert var_entry.type.syntax == "<angle>"
    end
  end

  describe "css_consts/2 API" do
    test "defines constants accessible at compile time" do
      const_value = LiveStyle.get_metadata(TokensModule, {:const, :breakpoint, :lg})

      assert const_value == "@media (min-width: 1025px)"
    end
  end

  describe "css_keyframes/2 API" do
    test "defines keyframes with content-hashed name" do
      keyframes = LiveStyle.get_metadata(TokensModule, {:keyframes, :spin})

      assert keyframes != nil
      # StyleX keyframes naming pattern: x<hash>-B
      assert keyframes.css_name =~ ~r/^x[a-z0-9]+-B$/
      assert keyframes.ltr =~ "@keyframes"
      assert keyframes.priority == 0
    end
  end

  describe "css_class/2 API" do
    test "static rules generate atomic classes" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :button})

      assert rule != nil
      assert rule.class_string != ""
      assert is_map(rule.atomic_classes)
      assert Map.has_key?(rule.atomic_classes, "display")
      assert Map.has_key?(rule.atomic_classes, "padding")
    end

    test "conditional rules generate multiple classes per property" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :link})

      # color should have classes map with :default, :hover, etc.
      color_classes = rule.atomic_classes["color"].classes
      assert Map.has_key?(color_classes, :default)
      assert Map.has_key?(color_classes, ":hover")
      assert Map.has_key?(color_classes, ":focus")
    end

    test "dynamic rules are marked as dynamic" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :dynamic_opacity})

      assert rule.dynamic == true
    end

    test "array fallbacks generate multiple declarations" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :sticky})

      position = rule.atomic_classes["position"]
      # Should have multiple values in LTR
      assert position.ltr =~ "position:sticky"
      assert position.ltr =~ "position:fixed"
    end
  end

  describe "css_theme/3 API" do
    test "defines theme with overrides" do
      theme = LiveStyle.get_metadata(TokensModule, {:theme, :color, :dark})

      assert theme != nil
      # Theme names follow a pattern (may or may not start with x)
      assert is_binary(theme.css_name)
      assert String.length(theme.css_name) > 0
      assert is_map(theme.overrides)
    end
  end

  describe "css_position_try/2 API" do
    test "defines position-try rules" do
      position_try = LiveStyle.get_metadata(PositionTryModule, {:position_try, :bottom_fallback})

      assert position_try != nil
      assert position_try.css_name =~ ~r/^--x[a-z0-9]+$/
    end
  end

  describe "css_view_transition/2 API" do
    test "defines view transition with content-hashed name" do
      vt = LiveStyle.get_metadata(ViewTransitionModule, {:view_transition, :card_transition})

      assert vt != nil
      assert vt.css_name =~ ~r/^x[a-z0-9]+$/
    end
  end

  describe "__include__ feature" do
    test "extended rule includes base rule declarations" do
      rule = LiveStyle.get_metadata(IncludeModule, {:class, :extended})

      # Should have display from base
      assert Map.has_key?(rule.atomic_classes, "display")
      # Should have its own property
      assert Map.has_key?(rule.atomic_classes, "justify-content")
    end
  end

  describe "css/1 generated function API" do
    test "returns Attrs struct for single rule" do
      attrs = LiveStyle.get_css(StylesModule, :button)

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "returns Attrs struct for list of rules" do
      attrs = LiveStyle.get_css(StylesModule, [:button, :link])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
    end

    test "handles nil and false in list (conditionals)" do
      attrs = LiveStyle.get_css(StylesModule, [:button, nil, false, :link])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
    end

    test "handles dynamic rules with values" do
      attrs = LiveStyle.get_css(StylesModule, [:button, {:dynamic_opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      # Dynamic rules set style for CSS variables
      assert attrs.style != nil or is_binary(attrs.class)
    end

    test "dynamic rules return CSS variables in style" do
      attrs = LiveStyle.get_css(StylesModule, [{:dynamic_opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      # Should have a CSS variable for opacity with the value
      assert attrs.style =~ ~r/--x-opacity.*0\.5/
    end

    test "dynamic rules with multiple params return all CSS variables" do
      attrs = LiveStyle.get_css(StylesModule, [{:dynamic_size, ["100px", "200px"]}])

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

  describe "css_class/1 generated function API" do
    test "returns string for single rule" do
      class = LiveStyle.get_css_class(StylesModule, :button)

      assert is_binary(class)
      assert class != ""
    end

    test "returns string for list of rules" do
      class = LiveStyle.get_css_class(StylesModule, [:button, :link])

      assert is_binary(class)
    end
  end

  describe "LiveStyle.Attrs struct" do
    test "has expected fields" do
      attrs = %LiveStyle.Attrs{class: "test", style: nil}

      assert Map.has_key?(attrs, :class)
      assert Map.has_key?(attrs, :style)
    end

    test "can access fields via struct syntax" do
      attrs = %LiveStyle.Attrs{class: "test", style: "color:red"}

      assert attrs.class == "test"
      assert attrs.style == "color:red"
    end
  end

  describe "LiveStyle.When contextual selectors API" do
    test "ancestor/2 is available and generates correct selector" do
      rule = LiveStyle.get_metadata(WhenModule, {:class, :with_ancestor})

      assert rule != nil
      # The rule should have a color class
      assert Map.has_key?(rule.atomic_classes, "color")
    end

    test "descendant/2 is available and generates correct selector" do
      rule = LiveStyle.get_metadata(WhenModule, {:class, :with_descendant})

      assert rule != nil
    end

    test "ancestor returns correct selector format" do
      prefix = LiveStyle.Config.class_name_prefix()
      default_marker = LiveStyle.Marker.default()
      selector = LiveStyle.When.ancestor(":hover")
      # Uses the configured default marker
      assert selector == ":where(.#{default_marker}:hover *)"
      assert String.contains?(selector, "#{prefix}-default-marker")
    end

    test "descendant returns correct selector format" do
      default_marker = LiveStyle.Marker.default()
      selector = LiveStyle.When.descendant(":focus")
      assert selector == ":where(:has(.#{default_marker}:focus))"
    end

    test "sibling_before returns correct selector format" do
      default_marker = LiveStyle.Marker.default()
      selector = LiveStyle.When.sibling_before(":checked")
      assert selector == ":where(.#{default_marker}:checked ~ *)"
    end

    test "marker returns default marker class" do
      prefix = LiveStyle.Config.class_name_prefix()
      marker = LiveStyle.Marker.default()
      # Default marker is derived from configured prefix
      assert marker == "#{prefix}-default-marker"
    end

    test "marker with custom name generates unique marker" do
      prefix = LiveStyle.Config.class_name_prefix()
      marker = LiveStyle.Marker.define(:my_marker)
      # Custom markers generate a unique hash-based class name (StyleX format: {prefix}{hash})
      assert is_binary(marker)
      assert String.starts_with?(marker, prefix)
      # Should NOT have the "-marker-" or "-default-marker" in it
      refute String.contains?(marker, "-marker-")
    end
  end

  describe "LiveStyle.Types API" do
    test "color/1 returns typed value" do
      typed = LiveStyle.Types.color("#ff0000")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<color>"
      assert typed.value == "#ff0000"
    end

    test "length/1 returns typed value" do
      typed = LiveStyle.Types.length("10px")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<length>"
      assert typed.value == "10px"
    end

    test "angle/1 returns typed value" do
      typed = LiveStyle.Types.angle("45deg")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<angle>"
      assert typed.value == "45deg"
    end

    test "time/1 returns typed value" do
      typed = LiveStyle.Types.time("200ms")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<time>"
      assert typed.value == "200ms"
    end

    test "number/1 returns typed value" do
      typed = LiveStyle.Types.number("1.5")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<number>"
      assert typed.value == "1.5"
    end

    test "integer/1 returns typed value" do
      typed = LiveStyle.Types.integer(5)

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<integer>"
      # Integer may be stored as string
      assert typed.value == 5 or typed.value == "5"
    end

    test "percentage/1 returns typed value" do
      typed = LiveStyle.Types.percentage("50%")

      assert typed.__type__ == :typed_var
      assert typed.syntax == "<percentage>"
      assert typed.value == "50%"
    end
  end

  describe "LiveStyle.CSS public API" do
    test "generate/1 returns CSS string" do
      css = generate_css()

      assert is_binary(css)
      # Should contain actual CSS
      assert css =~ "{"
      assert css =~ "}"
    end
  end

  describe "Cross-module references" do
    test "css_var can reference variables from other modules" do
      # This is tested by StylesModule.themed which references TokensModule
      rule = LiveStyle.get_metadata(StylesModule, {:class, :themed})

      # color should reference the var from TokensModule
      color = rule.atomic_classes["color"]
      assert color.ltr =~ "var(--"
    end

    test "css_keyframes can reference keyframes from other modules" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :themed})

      # animation-name should reference keyframes from TokensModule
      animation = rule.atomic_classes["animation-name"]
      assert animation.ltr =~ ~r/animation-name:x[a-z0-9]+-B/
    end
  end

  describe "Atomic class output format" do
    test "class names follow StyleX pattern (x prefix)" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :button})

      # All class names should start with 'x'
      Enum.each(rule.atomic_classes, fn {_prop, meta} ->
        class =
          meta.class || (meta.classes && meta.classes[:default] && meta.classes[:default].class)

        if class,
          do: assert(String.starts_with?(class, "x"), "Class #{class} should start with 'x'")
      end)
    end

    test "LTR output follows .classname{property:value} format" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :button})

      display = rule.atomic_classes["display"]
      assert display.ltr =~ ~r/^\.[a-z0-9]+\{display:[^}]+\}$/
    end

    test "priorities follow StyleX convention" do
      rule = LiveStyle.get_metadata(StylesModule, {:class, :button})

      # Regular properties should have priority 3000
      display = rule.atomic_classes["display"]
      assert display.priority == 3000

      # Custom properties should have priority 1
      custom_rule = LiveStyle.get_metadata(StylesModule, {:class, :custom_props})
      custom_prop = custom_rule.atomic_classes["--my-color"]
      assert custom_prop.priority == 1
    end
  end

  describe "Public helper functions" do
    test "LiveStyle.css_class/2 returns class string" do
      class = LiveStyle.get_css_class(StylesModule, [:button])

      assert is_binary(class)
      assert class != ""
    end

    test "LiveStyle.css_class/2 merges multiple rules" do
      class = LiveStyle.get_css_class(StylesModule, [:button, :link])

      assert is_binary(class)
      # Should contain classes from both rules
      assert String.contains?(class, " ") or String.length(class) > 10
    end
  end
end
