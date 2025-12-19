defmodule LiveStyle.ShorthandTest do
  @moduledoc """
  Tests for CSS shorthand property handling.

  These tests ensure LiveStyle handles shorthand properties (margin, padding,
  border, etc.) correctly, including:
  - Priority ordering (shorthands < longhands)
  - Multi-value shorthand parsing
  - Shorthand-longhand interaction when merging

  StyleX Reference:
  - packages/@stylexjs/babel-plugin/__tests__/legacy/stylex-transform-legacy-shorthands-test.js
  - packages/@stylexjs/shared/src/utils/property-priorities.js
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Basic Shorthand Properties
  # ============================================================================

  defmodule BasicShorthands do
    use LiveStyle

    # Shorthand of shorthands (priority 1000)
    css_class(:margin_all, margin: "10px")
    css_class(:padding_all, padding: "10px")

    # Multi-value shorthands
    css_class(:margin_two_values, margin: "10px 20px")
    css_class(:margin_three_values, margin: "10px 20px 30px")
    css_class(:margin_four_values, margin: "10px 20px 30px 40px")

    # Padding variants
    css_class(:padding_two_values, padding: "5px 10px")
    css_class(:padding_four_values, padding: "5px 10px 15px 20px")
  end

  defmodule LonghandProperties do
    use LiveStyle

    # Physical longhands (priority 4000)
    css_class(:margin_top, margin_top: "10px")
    css_class(:margin_right, margin_right: "10px")
    css_class(:margin_bottom, margin_bottom: "10px")
    css_class(:margin_left, margin_left: "10px")

    css_class(:padding_top, padding_top: "10px")
    css_class(:padding_right, padding_right: "10px")
    css_class(:padding_bottom, padding_bottom: "10px")
    css_class(:padding_left, padding_left: "10px")
  end

  defmodule ShorthandOfLonghands do
    use LiveStyle

    # Shorthand of longhands (priority 2000)
    css_class(:margin_block, margin_block: "10px")
    css_class(:margin_inline, margin_inline: "10px")
    css_class(:padding_block, padding_block: "10px")
    css_class(:padding_inline, padding_inline: "10px")

    # Border shorthand of longhands
    css_class(:border_color, border_color: "red")
    css_class(:border_width, border_width: "1px")
    css_class(:border_style, border_style: "solid")
  end

  # ============================================================================
  # Border Shorthands
  # ============================================================================

  defmodule BorderShorthands do
    use LiveStyle

    # Border shorthand (priority 1000)
    css_class(:border_all, border: "1px solid red")

    # Border side shorthands (priority 2000)
    css_class(:border_top, border_top: "1px solid red")
    css_class(:border_right, border_right: "1px solid red")
    css_class(:border_bottom, border_bottom: "1px solid red")
    css_class(:border_left, border_left: "1px solid red")

    # Border property shorthands (priority 2000)
    css_class(:border_color, border_color: "red")
    css_class(:border_width, border_width: "1px")
    css_class(:border_style, border_style: "solid")

    # Border longhands (priority 4000)
    css_class(:border_top_color, border_top_color: "red")
    css_class(:border_top_width, border_top_width: "1px")
    css_class(:border_top_style, border_top_style: "solid")
  end

  # ============================================================================
  # Other Shorthands
  # ============================================================================

  defmodule OtherShorthands do
    use LiveStyle

    # Background (shorthand of shorthands - 1000)
    css_class(:background, background: "red")

    # Font (shorthand of shorthands - 1000)
    css_class(:font, font: "16px/1.5 Arial")

    # Flex (shorthand of shorthands - 1000)
    css_class(:flex, flex: "1 1 auto")

    # Transition (shorthand of shorthands - 1000)
    css_class(:transition, transition: "all 0.3s ease")

    # Animation (shorthand of shorthands - 1000)
    css_class(:animation, animation: "fade 1s ease")

    # Text decoration (shorthand of longhands - 2000)
    css_class(:text_decoration, text_decoration: "underline")

    # Outline (shorthand of longhands - 2000)
    css_class(:outline, outline: "1px solid blue")

    # Inset (shorthand of shorthands - 1000)
    css_class(:inset, inset: "10px")
  end

  # ============================================================================
  # Tests - Basic Shorthand Priority
  # ============================================================================

  describe "shorthand of shorthands priority (1000)" do
    test "margin shorthand has priority 1000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.margin_all"]

      assert rule.atomic_classes["margin"].priority == 1000
    end

    test "padding shorthand has priority 1000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.padding_all"]

      assert rule.atomic_classes["padding"].priority == 1000
    end

    test "background shorthand has priority 1000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.background"]

      assert rule.atomic_classes["background"].priority == 1000
    end

    test "flex shorthand has priority 2000" do
      # flex is shorthand of longhands (flex-grow, flex-shrink, flex-basis)
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.flex"]

      assert rule.atomic_classes["flex"].priority == 2000
    end

    test "transition shorthand has priority 2000" do
      # transition is shorthand of longhands (transition-property, etc.)
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.transition"]

      assert rule.atomic_classes["transition"].priority == 2000
    end

    test "inset shorthand has priority 1000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.inset"]

      assert rule.atomic_classes["inset"].priority == 1000
    end
  end

  describe "shorthand of longhands priority (2000)" do
    test "margin-block has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.ShorthandOfLonghands.margin_block"]

      assert rule.atomic_classes["margin-block"].priority == 2000
    end

    test "margin-inline has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.ShorthandOfLonghands.margin_inline"]

      assert rule.atomic_classes["margin-inline"].priority == 2000
    end

    test "border-color has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.ShorthandOfLonghands.border_color"]

      assert rule.atomic_classes["border-color"].priority == 2000
    end

    test "text-decoration has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.text_decoration"]

      assert rule.atomic_classes["text-decoration"].priority == 2000
    end

    test "outline has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.OtherShorthands.outline"]

      assert rule.atomic_classes["outline"].priority == 2000
    end
  end

  describe "physical longhand priority (4000)" do
    test "margin-top has priority 4000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.LonghandProperties.margin_top"]

      assert rule.atomic_classes["margin-top"].priority == 4000
    end

    test "margin-left has priority 4000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.LonghandProperties.margin_left"]

      assert rule.atomic_classes["margin-left"].priority == 4000
    end

    test "padding-top has priority 4000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.LonghandProperties.padding_top"]

      assert rule.atomic_classes["padding-top"].priority == 4000
    end

    test "border-top-color has priority 4000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_top_color"]

      assert rule.atomic_classes["border-top-color"].priority == 4000
    end
  end

  # ============================================================================
  # Tests - Border Shorthand Priority
  # ============================================================================

  describe "border shorthand priority" do
    test "border shorthand has priority 1000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_all"]

      assert rule.atomic_classes["border"].priority == 1000
    end

    test "border-top has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_top"]

      assert rule.atomic_classes["border-top"].priority == 2000
    end

    test "border-color has priority 2000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_color"]

      assert rule.atomic_classes["border-color"].priority == 2000
    end
  end

  # ============================================================================
  # Tests - Multi-value Shorthands
  # ============================================================================

  describe "multi-value margin shorthand" do
    test "two-value margin generates correct CSS" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.margin_two_values"]

      meta = rule.atomic_classes["margin"]
      assert meta.ltr =~ "margin:10px 20px"
    end

    test "three-value margin generates correct CSS" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.margin_three_values"]

      meta = rule.atomic_classes["margin"]
      assert meta.ltr =~ "margin:10px 20px 30px"
    end

    test "four-value margin generates correct CSS" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.margin_four_values"]

      meta = rule.atomic_classes["margin"]
      assert meta.ltr =~ "margin:10px 20px 30px 40px"
    end
  end

  describe "multi-value padding shorthand" do
    test "two-value padding generates correct CSS" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.padding_two_values"]

      meta = rule.atomic_classes["padding"]
      assert meta.ltr =~ "padding:5px 10px"
    end

    test "four-value padding generates correct CSS" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.padding_four_values"]

      meta = rule.atomic_classes["padding"]
      assert meta.ltr =~ "padding:5px 10px 15px 20px"
    end
  end

  # ============================================================================
  # Tests - Shorthand/Longhand Merge Behavior
  # ============================================================================

  defmodule MergeBehavior do
    use LiveStyle

    # When longhand follows shorthand, longhand wins for that specific property
    css_class(:shorthand_then_longhand,
      margin: "10px",
      margin_left: "20px"
    )

    # Shorthand should apply to all sides except the explicitly set longhand
    css_class(:longhand_then_shorthand,
      margin_left: "20px",
      margin: "10px"
    )

    # Multiple longhands after shorthand
    css_class(:mixed,
      padding: "5px",
      padding_top: "10px",
      padding_bottom: "15px"
    )
  end

  defmodule MergeRuntime do
    use LiveStyle

    css_class(:base, margin: "10px")
    css_class(:override, margin_left: "20px")

    def test_css(args), do: css(args)
  end

  describe "shorthand and longhand interaction" do
    test "longhand after shorthand in same rule both exist" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.MergeBehavior.shorthand_then_longhand"]

      # Both margin and margin-left should exist as separate atomic classes
      assert rule.atomic_classes["margin"] != nil
      assert rule.atomic_classes["margin-left"] != nil
    end

    test "shorthand after longhand in same rule - both exist" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.MergeBehavior.longhand_then_shorthand"]

      # Both should exist (CSS cascade will determine which wins)
      assert rule.atomic_classes["margin-left"] != nil
      assert rule.atomic_classes["margin"] != nil
    end

    test "multiple longhands after shorthand" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ShorthandTest.MergeBehavior.mixed"]

      # All should exist as separate atomic classes
      assert rule.atomic_classes["padding"] != nil
      assert rule.atomic_classes["padding-top"] != nil
      assert rule.atomic_classes["padding-bottom"] != nil
    end
  end

  describe "runtime merge behavior" do
    test "merging shorthand and longhand rules at runtime" do
      # When merging rules at runtime, both classes should be applied
      # and CSS cascade handles the priority
      attrs = MergeRuntime.test_css([:base, :override])

      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      # Should have classes from both rules
      # The actual winning value depends on CSS cascade (priority)
    end
  end

  # ============================================================================
  # Tests - Priority Ordering
  # ============================================================================

  describe "priority ordering ensures correct cascade" do
    test "shorthand < shorthand-of-longhands < longhand" do
      # Verify the priority ordering is correct
      # 1000 (shorthand) < 2000 (shorthand-of-longhands) < 4000 (longhand)

      manifest = get_manifest()

      margin_rule = manifest.rules["LiveStyle.ShorthandTest.BasicShorthands.margin_all"]

      margin_block_rule =
        manifest.rules["LiveStyle.ShorthandTest.ShorthandOfLonghands.margin_block"]

      margin_top_rule = manifest.rules["LiveStyle.ShorthandTest.LonghandProperties.margin_top"]

      margin_priority = margin_rule.atomic_classes["margin"].priority
      margin_block_priority = margin_block_rule.atomic_classes["margin-block"].priority
      margin_top_priority = margin_top_rule.atomic_classes["margin-top"].priority

      assert margin_priority < margin_block_priority
      assert margin_block_priority < margin_top_priority
    end

    test "border shorthand < border-top < border-top-color" do
      manifest = get_manifest()

      border_rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_all"]
      border_top_rule = manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_top"]

      border_top_color_rule =
        manifest.rules["LiveStyle.ShorthandTest.BorderShorthands.border_top_color"]

      border_priority = border_rule.atomic_classes["border"].priority
      border_top_priority = border_top_rule.atomic_classes["border-top"].priority

      border_top_color_priority =
        border_top_color_rule.atomic_classes["border-top-color"].priority

      assert border_priority < border_top_priority
      assert border_top_priority < border_top_color_priority
    end
  end
end
