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
    css_class(:opacity, fn opacity -> [opacity: opacity] end)

    # Single parameter with different property
    css_class(:color, fn color -> [color: color] end)

    # Single parameter with background
    css_class(:background, fn bg -> [background_color: bg] end)
  end

  defmodule MultiParamDynamic do
    use LiveStyle

    # Multiple parameters
    css_class(:size, fn width, height -> [width: width, height: height] end)

    # Multiple parameters - different properties
    css_class(:position, fn top, left -> [top: top, left: left] end)

    # Three parameters
    css_class(:box, fn width, height, margin ->
      [width: width, height: height, margin: margin]
    end)
  end

  defmodule MixedStaticDynamic do
    use LiveStyle

    # Static rule for comparison
    css_class(:static_box,
      display: "flex",
      padding: "10px"
    )

    # Dynamic rule
    css_class(:dynamic_color, fn color -> [color: color] end)
  end

  # ============================================================================
  # Basic Dynamic Styles Tests
  # ============================================================================

  describe "basic dynamic styles" do
    test "single parameter dynamic rule is marked as dynamic" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      assert rule.dynamic == true
    end

    test "single parameter dynamic rule has param_names" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      assert rule.param_names == [:opacity]
    end

    test "single parameter dynamic rule has all_props" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      assert :opacity in rule.all_props
    end

    test "dynamic rule has class_string" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      assert is_binary(rule.class_string)
      assert rule.class_string != ""
    end

    test "dynamic rule atomic_classes reference CSS variables" do
      # StyleX: .xl8spv7{background-color:var(--x-backgroundColor)}
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      # Check that opacity class uses var(--x-opacity)
      opacity_class = rule.atomic_classes["opacity"]
      # Dynamic rules store var reference in :value and :var keys
      assert opacity_class.value =~ "var(--x-opacity)"
      assert opacity_class.var == "--x-opacity"
    end

    test "different dynamic rules have different class names" do
      opacity_rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      color_rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :color})

      assert opacity_rule.class_string != color_rule.class_string
    end
  end

  describe "multi-parameter dynamic styles" do
    test "multi-param dynamic rule has correct param_names" do
      rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.MultiParamDynamic, {:class, :size})

      assert rule.param_names == [:width, :height]
    end

    test "multi-param dynamic rule has all properties" do
      rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.MultiParamDynamic, {:class, :size})

      assert :width in rule.all_props
      assert :height in rule.all_props
    end

    test "multi-param dynamic rule generates multiple CSS variable references" do
      rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.MultiParamDynamic, {:class, :size})

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      # Dynamic rules store var reference in :value and :var keys
      assert width_class.value =~ "var(--x-width)"
      assert width_class.var == "--x-width"
      assert height_class.value =~ "var(--x-height)"
      assert height_class.var == "--x-height"
    end

    test "three-param dynamic rule works correctly" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.MultiParamDynamic, {:class, :box})

      assert rule.param_names == [:width, :height, :margin]
      assert :width in rule.all_props
      assert :height in rule.all_props
      assert :margin in rule.all_props
    end
  end

  describe "static vs dynamic rules" do
    test "static rule is not marked as dynamic" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.DynamicStylesTest.MixedStaticDynamic,
          {:class, :static_box}
        )

      assert rule.dynamic == false
    end

    test "dynamic rule is marked as dynamic" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.DynamicStylesTest.MixedStaticDynamic,
          {:class, :dynamic_color}
        )

      assert rule.dynamic == true
    end

    test "static rule has declarations" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.DynamicStylesTest.MixedStaticDynamic,
          {:class, :static_box}
        )

      assert rule.declarations != nil
    end
  end

  # ============================================================================
  # Dynamic Style Runtime Behavior
  # ============================================================================

  defmodule RuntimeDynamic do
    use LiveStyle

    css_class(:opacity, fn opacity -> [opacity: opacity] end)
    css_class(:colors, fn bg, fg -> [background_color: bg, color: fg] end)
    css_class(:static_base, display: "block", padding: "10px")
  end

  describe "dynamic style runtime behavior" do
    test "dynamic rule returns attrs with style containing CSS variables" do
      attrs = LiveStyle.get_css(RuntimeDynamic, [{:opacity, ["0.5"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      assert attrs.style =~ "--x-opacity"
      assert attrs.style =~ "0.5"
    end

    test "multi-param dynamic rule returns all CSS variables in style" do
      attrs = LiveStyle.get_css(RuntimeDynamic, [{:colors, ["red", "blue"]}])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.style)
      assert attrs.style =~ "--x-background-color"
      assert attrs.style =~ "red"
      assert attrs.style =~ "--x-color"
      assert attrs.style =~ "blue"
    end

    test "mixing static and dynamic rules works" do
      attrs = LiveStyle.get_css(RuntimeDynamic, [:static_base, {:opacity, ["0.8"]}])

      assert %LiveStyle.Attrs{} = attrs
      # Should have classes from both rules
      assert is_binary(attrs.class)
      # Should have style from dynamic rule
      assert is_binary(attrs.style)
      assert attrs.style =~ "0.8"
    end

    test "static rule alone returns no style attribute" do
      attrs = LiveStyle.get_css(RuntimeDynamic, [:static_base])

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
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      opacity_class = rule.atomic_classes["opacity"]
      assert opacity_class.var =~ "--x-opacity"
    end

    test "CSS variable names convert property names correctly" do
      rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :background})

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
    css_class(:transform, fn transform -> [transform: transform] end)

    # Dynamic with shorthand property
    css_class(:margin, fn margin -> [margin: margin] end)

    # Dynamic with custom property
    css_class(:custom, fn value -> [{:"--custom-var", value}] end)
  end

  describe "edge cases" do
    test "dynamic transform property works" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.EdgeCases, {:class, :transform})

      assert rule.dynamic == true
      transform_class = rule.atomic_classes["transform"]
      assert transform_class.value =~ "var(--x-transform)"
      assert transform_class.var == "--x-transform"
    end

    test "dynamic shorthand property works" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.EdgeCases, {:class, :margin})

      assert rule.dynamic == true
      margin_class = rule.atomic_classes["margin"]
      assert margin_class.value =~ "var(--x-margin)"
      assert margin_class.var == "--x-margin"
    end

    test "dynamic custom property works" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.EdgeCases, {:class, :custom})

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
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      opacity_class = rule.atomic_classes["opacity"]
      assert is_binary(opacity_class.class)
      assert opacity_class.class =~ ~r/^x[a-z0-9]+$/
    end

    test "dynamic width/height have class names" do
      rule =
        LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.MultiParamDynamic, {:class, :size})

      width_class = rule.atomic_classes["width"]
      height_class = rule.atomic_classes["height"]

      assert is_binary(width_class.class)
      assert is_binary(height_class.class)
    end

    test "dynamic shorthand has class name" do
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.EdgeCases, {:class, :margin})

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
      rule = LiveStyle.get_metadata(LiveStyle.DynamicStylesTest.BasicDynamic, {:class, :opacity})

      # The class_string should be a valid CSS class name
      assert is_binary(rule.class_string)
      assert rule.class_string =~ ~r/^[a-z0-9 ]+$/
    end
  end

  # ============================================================================
  # Property Prefixing Tests
  # ============================================================================

  defmodule DynamicWithPrefixedProperty do
    use LiveStyle

    # background-clip requires -webkit-background-clip for Safari
    css_class(:clip, fn clip -> [background_clip: clip] end)
  end

  describe "property prefixing" do
    setup do
      # Store original config
      original_prefix_css = Application.get_env(:live_style, :prefix_css)

      on_exit(fn ->
        # Restore original config
        if original_prefix_css do
          Application.put_env(:live_style, :prefix_css, original_prefix_css)
        else
          Application.delete_env(:live_style, :prefix_css)
        end
      end)

      :ok
    end

    test "dynamic classes get property prefixing applied" do
      # Configure a prefix_css function that adds -webkit-background-clip
      Application.put_env(:live_style, :prefix_css, fn property, value ->
        if property == "background-clip" do
          "-webkit-background-clip:#{value};background-clip:#{value}"
        else
          "#{property}:#{value}"
        end
      end)

      # The CSS rule generator uses Config.apply_prefix_css when building rules
      # generate_css() calls the rule generator which applies the prefix_css config
      css = generate_css()

      # The CSS should include both the prefixed and standard properties for dynamic class
      assert css =~ "-webkit-background-clip:var(--x-background-clip)"
      assert css =~ "background-clip:var(--x-background-clip)"
    end

    test "dynamic class has correct structure" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.DynamicStylesTest.DynamicWithPrefixedProperty,
          {:class, :clip}
        )

      # Dynamic class should have the background-clip property with a CSS variable
      clip_class = rule.atomic_classes["background-clip"]
      assert clip_class != nil
      assert clip_class.value == "var(--x-background-clip)"
      assert clip_class.var == "--x-background-clip"
    end
  end
end
