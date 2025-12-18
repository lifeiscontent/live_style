defmodule LiveStyle.DynamicStylesTest do
  @moduledoc """
  Tests for dynamic styles (function-based rules).

  These tests mirror StyleX's dynamic styles functionality where rules can
  be defined as functions that accept parameters and generate CSS variables
  at runtime.

  StyleX Reference:
  - packages/@stylexjs/babel-plugin/__tests__/transform-stylex-create-test.js (dynamic styles section)
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Basic Dynamic Styles
  # ============================================================================

  defmodule BasicDynamic do
    use LiveStyle

    # Single parameter dynamic rule
    css_rule(:opacity, fn opacity -> [opacity: opacity] end)

    # Single parameter with different property
    css_rule(:color, fn color -> [color: color] end)

    # Single parameter with background
    css_rule(:background, fn bg -> [background_color: bg] end)
  end

  defmodule MultiParamDynamic do
    use LiveStyle

    # Multiple parameters
    css_rule(:size, fn width, height -> [width: width, height: height] end)

    # Multiple parameters - different properties
    css_rule(:position, fn top, left -> [top: top, left: left] end)

    # Three parameters
    css_rule(:box, fn width, height, margin ->
      [width: width, height: height, margin: margin]
    end)
  end

  defmodule MixedStaticDynamic do
    use LiveStyle

    # Static rule for comparison
    css_rule(:static_box,
      display: "flex",
      padding: "10px"
    )

    # Dynamic rule
    css_rule(:dynamic_color, fn color -> [color: color] end)
  end

  # ============================================================================
  # Basic Dynamic Styles Tests
  # ============================================================================

  describe "basic dynamic styles" do
    test "single parameter dynamic rule is marked as dynamic" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      assert rule.dynamic == true
    end

    test "single parameter dynamic rule has param_names" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      assert rule.param_names == [:opacity]
    end

    test "single parameter dynamic rule has all_props" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      assert :opacity in rule.all_props
    end

    test "dynamic rule has class_string" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      assert is_binary(rule.class_string)
      assert rule.class_string != ""
    end

    test "dynamic rule atomic_classes reference CSS variables" do
      # StyleX: .xl8spv7{background-color:var(--x-backgroundColor)}
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      # Check that opacity class uses var(--x-opacity)
      opacity_class = rule.atomic_classes["opacity"]
      # Dynamic rules store var reference in :value and :var keys
      assert opacity_class.value =~ "var(--x-opacity)"
      assert opacity_class.var == "--x-opacity"
    end

    test "different dynamic rules have different class names" do
      manifest = get_manifest()
      opacity_rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]
      color_rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.color"]

      assert opacity_rule.class_string != color_rule.class_string
    end
  end

  describe "multi-parameter dynamic styles" do
    test "multi-param dynamic rule has correct param_names" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MultiParamDynamic.size"]

      assert rule.param_names == [:width, :height]
    end

    test "multi-param dynamic rule has all properties" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MultiParamDynamic.size"]

      assert :width in rule.all_props
      assert :height in rule.all_props
    end

    test "multi-param dynamic rule generates multiple CSS variable references" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MultiParamDynamic.size"]

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      # Dynamic rules store var reference in :value and :var keys
      assert width_class.value =~ "var(--x-width)"
      assert width_class.var == "--x-width"
      assert height_class.value =~ "var(--x-height)"
      assert height_class.var == "--x-height"
    end

    test "three-param dynamic rule works correctly" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MultiParamDynamic.box"]

      assert rule.param_names == [:width, :height, :margin]
      assert :width in rule.all_props
      assert :height in rule.all_props
      assert :margin in rule.all_props
    end
  end

  describe "static vs dynamic rules" do
    test "static rule is not marked as dynamic" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MixedStaticDynamic.static_box"]

      assert rule.dynamic == false
    end

    test "dynamic rule is marked as dynamic" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MixedStaticDynamic.dynamic_color"]

      assert rule.dynamic == true
    end

    test "static rule has declarations" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MixedStaticDynamic.static_box"]

      assert rule.declarations != nil
    end
  end

  # ============================================================================
  # Dynamic Style Runtime Behavior
  # ============================================================================

  defmodule RuntimeDynamic do
    use LiveStyle

    css_rule(:opacity, fn opacity -> [opacity: opacity] end)
    css_rule(:colors, fn bg, fg -> [background_color: bg, color: fg] end)
    css_rule(:static_base, display: "block", padding: "10px")

    def test_css(args), do: css(args)
  end

  describe "dynamic style runtime behavior" do
    test "dynamic rule returns attrs with style containing CSS variables" do
      attrs = RuntimeDynamic.test_css([{:opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      assert attrs.style =~ "--x-opacity"
      assert attrs.style =~ "0.5"
    end

    test "multi-param dynamic rule returns all CSS variables in style" do
      attrs = RuntimeDynamic.test_css([{:colors, ["red", "blue"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.style)
      assert attrs.style =~ "--x-background-color"
      assert attrs.style =~ "red"
      assert attrs.style =~ "--x-color"
      assert attrs.style =~ "blue"
    end

    test "mixing static and dynamic rules works" do
      attrs = RuntimeDynamic.test_css([:static_base, {:opacity, ["0.8"]}])

      assert %LiveStyle.Attrs{} = attrs
      # Should have classes from both rules
      assert is_binary(attrs.class)
      # Should have style from dynamic rule
      assert is_binary(attrs.style)
      assert attrs.style =~ "0.8"
    end

    test "static rule alone returns no style attribute" do
      attrs = RuntimeDynamic.test_css([:static_base])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      # Static-only should have nil style (no CSS variables needed)
      assert attrs.style == nil or attrs.style == ""
    end
  end

  # ============================================================================
  # CSS Variable Generation
  # ============================================================================

  describe "CSS variable naming" do
    test "CSS variable names use --x- prefix" do
      # StyleX uses --x-propertyName format for dynamic values
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      opacity_class = rule.atomic_classes["opacity"]
      assert opacity_class.var =~ "--x-opacity"
    end

    test "CSS variable names convert property names correctly" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.background"]

      bg_class = rule.atomic_classes["background-color"]
      assert bg_class.var =~ "--x-background-color"
    end
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  defmodule EdgeCases do
    use LiveStyle

    # Dynamic with transform property
    css_rule(:transform, fn transform -> [transform: transform] end)

    # Dynamic with shorthand property
    css_rule(:margin, fn margin -> [margin: margin] end)

    # Dynamic with custom property
    css_rule(:custom, fn value -> [{:"--custom-var", value}] end)
  end

  describe "edge cases" do
    test "dynamic transform property works" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.EdgeCases.transform"]

      assert rule.dynamic == true
      transform_class = rule.atomic_classes["transform"]
      assert transform_class.value =~ "var(--x-transform)"
      assert transform_class.var == "--x-transform"
    end

    test "dynamic shorthand property works" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.EdgeCases.margin"]

      assert rule.dynamic == true
      margin_class = rule.atomic_classes["margin"]
      assert margin_class.value =~ "var(--x-margin)"
      assert margin_class.var == "--x-margin"
    end

    test "dynamic custom property works" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.EdgeCases.custom"]

      assert rule.dynamic == true
      custom_class = rule.atomic_classes["--custom-var"]
      # Custom properties get --x- prefix like other properties
      assert custom_class.value =~ "var(--x---custom-var)"
    end
  end

  # ============================================================================
  # Priority Tests
  # ============================================================================

  describe "dynamic style structure" do
    test "dynamic styles have class names" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      opacity_class = rule.atomic_classes["opacity"]
      assert is_binary(opacity_class.class)
      assert opacity_class.class =~ ~r/^x[a-z0-9]+$/
    end

    test "dynamic width/height have class names" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.MultiParamDynamic.size"]

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      assert is_binary(width_class.class)
      assert is_binary(height_class.class)
    end

    test "dynamic shorthand has class name" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.EdgeCases.margin"]

      margin_class = rule.atomic_classes["margin"]
      assert is_binary(margin_class.class)
    end
  end

  # ============================================================================
  # CSS Output Tests
  # ============================================================================

  describe "CSS output" do
    test "generates @property and @keyframes rules" do
      # CSS output includes various at-rules
      css = generate_css()

      # CSS should include @property rules (from typed vars)
      assert css =~ "@property"

      # CSS should include @keyframes rules
      assert css =~ "@keyframes"
    end

    test "class_string contains valid class names" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.DynamicStylesTest.BasicDynamic.opacity"]

      # The class_string should be a valid CSS class name
      assert is_binary(rule.class_string)
      assert rule.class_string =~ ~r/^[a-z0-9 ]+$/
    end
  end
end
