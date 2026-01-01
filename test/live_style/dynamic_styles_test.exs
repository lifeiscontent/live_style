defmodule LiveStyle.DynamicStylesTest do
  @moduledoc """
  Tests for dynamic styles (function-based rules).

  These tests mirror StyleX's dynamic styles functionality where rules can
  be defined as functions that accept parameters and generate CSS variables
  at runtime.

  StyleX Reference:
  - packages/@stylexjs/babel-plugin/__tests__/transform-stylex-create-test.js (dynamic styles section)
  """
  use LiveStyle.TestCase
  use Snapshy

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.Class

  # ============================================================================
  # Basic Dynamic Styles
  # ============================================================================

  defmodule BasicDynamic do
    use LiveStyle

    # Single parameter dynamic rule
    class(:opacity, fn opacity -> [opacity: opacity] end)

    # Single parameter with different property
    class(:color, fn color -> [color: color] end)

    # Single parameter with background
    class(:background, fn bg -> [background_color: bg] end)
  end

  defmodule MultiParamDynamic do
    use LiveStyle

    # Multiple parameters
    class(:size, fn width, height -> [width: width, height: height] end)

    # Multiple parameters - different properties
    class(:position, fn top, left -> [top: top, left: left] end)

    # Three parameters
    class(:box, fn width, height, margin ->
      [width: width, height: height, margin: margin]
    end)
  end

  defmodule MixedStaticDynamic do
    use LiveStyle

    # Static rule for comparison
    class(:static_box,
      display: "flex",
      padding: "10px"
    )

    # Dynamic rule
    class(:dynamic_color, fn color -> [color: color] end)
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  defmodule EdgeCases do
    use LiveStyle

    # Dynamic with transform property
    class(:transform, fn transform -> [transform: transform] end)

    # Dynamic with shorthand property
    class(:margin, fn margin -> [margin: margin] end)

    # Dynamic with custom property
    class(:custom, fn value -> [{:"--custom-var", value}] end)
  end

  # ============================================================================
  # Runtime Dynamic
  # ============================================================================

  defmodule RuntimeDynamic do
    use LiveStyle

    class(:opacity, fn opacity -> [opacity: opacity] end)
    class(:colors, fn bg, fg -> [background_color: bg, color: fg] end)
    class(:static_base, display: "block", padding: "10px")
  end

  # ============================================================================
  # Snapshot Tests - CSS Output
  # ============================================================================

  describe "dynamic style CSS output" do
    test_snapshot "single param dynamic opacity CSS output" do
      class_string = Compiler.get_css_class(BasicDynamic, [:opacity])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "single param dynamic color CSS output" do
      class_string = Compiler.get_css_class(BasicDynamic, [:color])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "single param dynamic background CSS output" do
      class_string = Compiler.get_css_class(BasicDynamic, [:background])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "multi-param size dynamic CSS output" do
      class_string = Compiler.get_css_class(MultiParamDynamic, [:size])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "three-param box dynamic CSS output" do
      class_string = Compiler.get_css_class(MultiParamDynamic, [:box])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "dynamic transform property CSS output" do
      class_string = Compiler.get_css_class(EdgeCases, [:transform])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "dynamic shorthand margin CSS output" do
      class_string = Compiler.get_css_class(EdgeCases, [:margin])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "dynamic custom property CSS output" do
      class_string = Compiler.get_css_class(EdgeCases, [:custom])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Runtime Style Output
  # ============================================================================

  describe "runtime style output" do
    test_snapshot "dynamic rule with value returns style" do
      attrs = Compiler.get_css(RuntimeDynamic, [{:opacity, ["0.5"]}])

      "class: #{attrs.class}\nstyle: #{attrs.style}"
    end

    test_snapshot "multi-param dynamic returns all variables" do
      attrs = Compiler.get_css(RuntimeDynamic, [{:colors, ["red", "blue"]}])

      "class: #{attrs.class}\nstyle: #{attrs.style}"
    end

    test_snapshot "mixing static and dynamic rules" do
      attrs = Compiler.get_css(RuntimeDynamic, [:static_base, {:opacity, ["0.8"]}])

      "class: #{attrs.class}\nstyle: #{attrs.style}"
    end

    test_snapshot "static rule only output" do
      attrs = Compiler.get_css(RuntimeDynamic, [:static_base])

      "class: #{attrs.class}\nstyle: #{attrs.style || "(nil)"}"
    end
  end

  # ============================================================================
  # Internal Structure Tests (keeping as assertions)
  # ============================================================================

  describe "basic dynamic styles internal structure" do
    test "single parameter dynamic rule is marked as dynamic" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      assert rule.dynamic == true
    end

    test "single parameter dynamic rule has param_names" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      assert rule.param_names == [:opacity]
    end

    test "single parameter dynamic rule has all_props" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      assert :opacity in rule.all_props
    end

    test "dynamic rule has class_string" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      assert is_binary(rule.class_string)
      assert rule.class_string != ""
    end

    test "dynamic rule atomic_classes reference CSS variables" do
      # StyleX: .xl8spv7{background-color:var(--x-backgroundColor)}
      rule = Class.lookup!({BasicDynamic, :opacity})

      # Check that opacity class uses var(--x-opacity)
      opacity_class = rule.atomic_classes["opacity"]
      # Dynamic rules store var reference in :value and :var keys
      assert opacity_class.value =~ "var(--x-opacity)"
      assert opacity_class.var == "--x-opacity"
    end

    test "different dynamic rules have different class names" do
      opacity_rule = Class.lookup!({BasicDynamic, :opacity})
      color_rule = Class.lookup!({BasicDynamic, :color})

      assert opacity_rule.class_string != color_rule.class_string
    end
  end

  describe "multi-parameter dynamic styles internal structure" do
    test "multi-param dynamic rule has correct param_names" do
      rule = Class.lookup!({MultiParamDynamic, :size})

      assert rule.param_names == [:width, :height]
    end

    test "multi-param dynamic rule has all properties" do
      rule = Class.lookup!({MultiParamDynamic, :size})

      assert :width in rule.all_props
      assert :height in rule.all_props
    end

    test "multi-param dynamic rule generates multiple CSS variable references" do
      rule = Class.lookup!({MultiParamDynamic, :size})

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      # Dynamic rules store var reference in :value and :var keys
      assert width_class.value =~ "var(--x-width)"
      assert width_class.var == "--x-width"
      assert height_class.value =~ "var(--x-height)"
      assert height_class.var == "--x-height"
    end

    test "three-param dynamic rule works correctly" do
      rule = Class.lookup!({MultiParamDynamic, :box})

      assert rule.param_names == [:width, :height, :margin]
      assert :width in rule.all_props
      assert :height in rule.all_props
      assert :margin in rule.all_props
    end
  end

  describe "static vs dynamic rules" do
    test "static rule is not marked as dynamic" do
      rule = Class.lookup!({MixedStaticDynamic, :static_box})

      assert rule.dynamic == false
    end

    test "dynamic rule is marked as dynamic" do
      rule = Class.lookup!({MixedStaticDynamic, :dynamic_color})

      assert rule.dynamic == true
    end

    test "static rule has declarations" do
      rule = Class.lookup!({MixedStaticDynamic, :static_box})

      assert rule.declarations != nil
    end
  end

  describe "CSS variable naming" do
    test "CSS variable names use --x- prefix" do
      # StyleX uses --x-propertyName format for dynamic values
      rule = Class.lookup!({BasicDynamic, :opacity})

      opacity_class = rule.atomic_classes["opacity"]
      assert opacity_class.var =~ "--x-opacity"
    end

    test "CSS variable names convert property names correctly" do
      rule = Class.lookup!({BasicDynamic, :background})

      bg_class = rule.atomic_classes["background-color"]
      assert bg_class.var =~ "--x-background-color"
    end
  end

  describe "edge cases internal structure" do
    test "dynamic transform property works" do
      rule = Class.lookup!({EdgeCases, :transform})

      assert rule.dynamic == true
      transform_class = rule.atomic_classes["transform"]
      assert transform_class.value =~ "var(--x-transform)"
      assert transform_class.var == "--x-transform"
    end

    test "dynamic shorthand property works" do
      rule = Class.lookup!({EdgeCases, :margin})

      assert rule.dynamic == true
      margin_class = rule.atomic_classes["margin"]
      assert margin_class.value =~ "var(--x-margin)"
      assert margin_class.var == "--x-margin"
    end

    test "dynamic custom property works" do
      rule = Class.lookup!({EdgeCases, :custom})

      assert rule.dynamic == true
      custom_class = rule.atomic_classes["--custom-var"]
      # Custom properties get --x- prefix like other properties
      assert custom_class.value =~ "var(--x---custom-var)"
    end
  end

  describe "dynamic style class structure" do
    test "dynamic styles have class names" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      opacity_class = rule.atomic_classes["opacity"]
      assert is_binary(opacity_class.class)
      assert opacity_class.class =~ ~r/^x[a-z0-9]+$/
    end

    test "dynamic width/height have class names" do
      rule = Class.lookup!({MultiParamDynamic, :size})

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      assert is_binary(width_class.class)
      assert is_binary(height_class.class)
    end

    test "dynamic shorthand has class name" do
      rule = Class.lookup!({EdgeCases, :margin})

      margin_class = rule.atomic_classes["margin"]
      assert is_binary(margin_class.class)
    end
  end

  describe "CSS output structure" do
    test "generates @property and @keyframes rules" do
      # CSS output includes various at-rules
      css = Compiler.generate_css()

      # CSS should include @property rules (from typed vars)
      assert css =~ "@property"

      # CSS should include @keyframes rules
      assert css =~ "@keyframes"
    end

    test "class_string contains valid class names" do
      rule = Class.lookup!({BasicDynamic, :opacity})

      # The class_string should be a valid CSS class name
      assert is_binary(rule.class_string)
      assert rule.class_string =~ ~r/^[a-z0-9 ]+$/
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp extract_all_rules(class_string) do
    css = Compiler.generate_css()

    class_string
    |> String.split(" ")
    |> Enum.flat_map(fn class_name ->
      extract_rules_for_class(css, class_name)
    end)
    |> Enum.uniq()
  end

  defp extract_rules_for_class(css, class_name) do
    escaped_class = Regex.escape(class_name)

    patterns = [
      # Simple rules
      ~r/\.#{escaped_class}\{[^}]+\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, css) |> List.flatten()
    end)
  end
end
