defmodule LiveStyle.LogicalPropertiesTest do
  @moduledoc """
  Tests for CSS logical properties and RTL support.

  These tests mirror StyleX's transform-logical-properties-test.js and
  transform-logical-values-test.js to ensure LiveStyle handles bidirectional
  CSS the same way StyleX does.

  StyleX's default mode is "application-order" which:
  - Keeps modern logical inline properties as-is (margin-inline-start stays margin-inline-start)
  - Converts legacy properties (margin-start → margin-left)
  - Converts logical values (float: inline-start → float: left with RTL)
  - Converts block longhands to physical (margin-block-start → margin-top)
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Logical Values (float, clear, text-align)
  # These need polyfill (browser doesn't support inline-start/inline-end values)
  # ============================================================================

  defmodule LogicalValues do
    use LiveStyle

    # float: inline-start → float: left (LTR), float: right (RTL)
    css_rule(:float_start, float: "inline-start")
    # float: inline-end → float: right (LTR), float: left (RTL)
    css_rule(:float_end, float: "inline-end")

    # clear: inline-start → clear: left (LTR), clear: right (RTL)
    css_rule(:clear_start, clear: "inline-start")
    # clear: inline-end → clear: right (LTR), clear: left (RTL)
    css_rule(:clear_end, clear: "inline-end")

    # text-align: start/end - browser handles these natively, NO transformation
    css_rule(:text_align_start, text_align: "start")
    css_rule(:text_align_end, text_align: "end")
  end

  # ============================================================================
  # Modern Logical Properties (application-order mode - stay as-is)
  # Browser handles RTL automatically for these
  # ============================================================================

  defmodule LogicalPropertiesModern do
    use LiveStyle

    # These should stay as logical properties (NOT converted to physical)

    # Border inline (shorthands stay as-is)
    css_rule(:border_inline_color, border_inline_color: "red")

    # Border inline longhands (stay as logical)
    css_rule(:border_inline_start_color, border_inline_start_color: "red")
    css_rule(:border_inline_end_color, border_inline_end_color: "red")

    # Margin inline shorthand (stays as-is)
    css_rule(:margin_inline, margin_inline: "10px")

    # Margin inline longhands (stay as logical)
    css_rule(:margin_inline_start, margin_inline_start: "10px")
    css_rule(:margin_inline_end, margin_inline_end: "10px")

    # Padding inline shorthand
    css_rule(:padding_inline, padding_inline: "10px")

    # Padding inline longhands
    css_rule(:padding_inline_start, padding_inline_start: "10px")
    css_rule(:padding_inline_end, padding_inline_end: "10px")

    # Inset inline shorthand
    css_rule(:inset_inline, inset_inline: "10px")

    # Inset inline longhands
    css_rule(:inset_inline_start, inset_inline_start: "10px")
    css_rule(:inset_inline_end, inset_inline_end: "10px")

    # Block shorthands (stay as-is)
    css_rule(:margin_block, margin_block: "10px")

    # Block longhands (converted to physical - top/bottom don't flip)
    css_rule(:margin_block_start, margin_block_start: "10px")
    css_rule(:margin_block_end, margin_block_end: "10px")
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "logical values - float property" do
    test "float: inline-start generates LTR (left) and RTL (right)" do
      # StyleX: ltr: ".x1kmio9f{float:left}", rtl: ".x1kmio9f{float:right}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.float_start"]

      meta = rule.atomic_classes["float"]
      assert meta.class == "x1kmio9f"
      assert meta.ltr == ".x1kmio9f{float:left}"
      assert meta.rtl == "html[dir=\"rtl\"] .x1kmio9f{float:right}"
      assert meta.priority == 3000
    end

    test "float: inline-end generates LTR (right) and RTL (left)" do
      # StyleX: ltr: ".x1h0q493{float:right}", rtl: ".x1h0q493{float:left}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.float_end"]

      meta = rule.atomic_classes["float"]
      assert meta.class == "x1h0q493"
      assert meta.ltr == ".x1h0q493{float:right}"
      assert meta.rtl == "html[dir=\"rtl\"] .x1h0q493{float:left}"
      assert meta.priority == 3000
    end
  end

  describe "logical values - clear property" do
    test "clear: inline-start generates LTR (left) and RTL (right)" do
      # StyleX: ltr: ".x18lmvvi{clear:left}", rtl: ".x18lmvvi{clear:right}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.clear_start"]

      meta = rule.atomic_classes["clear"]
      assert meta.class == "x18lmvvi"
      assert meta.ltr == ".x18lmvvi{clear:left}"
      assert meta.rtl == "html[dir=\"rtl\"] .x18lmvvi{clear:right}"
      assert meta.priority == 3000
    end

    test "clear: inline-end generates LTR (right) and RTL (left)" do
      # StyleX: ltr: ".xof8tvn{clear:right}", rtl: ".xof8tvn{clear:left}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.clear_end"]

      meta = rule.atomic_classes["clear"]
      assert meta.class == "xof8tvn"
      assert meta.ltr == ".xof8tvn{clear:right}"
      assert meta.rtl == "html[dir=\"rtl\"] .xof8tvn{clear:left}"
      assert meta.priority == 3000
    end
  end

  describe "logical values - text-align property" do
    test "text-align: start is NOT transformed (browser handles RTL)" do
      # StyleX: ltr: ".x1yc453h{text-align:start}" (NO RTL override)
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.text_align_start"]

      meta = rule.atomic_classes["text-align"]
      assert meta.class == "x1yc453h"
      assert meta.ltr == ".x1yc453h{text-align:start}"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "text-align: end is NOT transformed (browser handles RTL)" do
      # StyleX: ltr: ".xp4054r{text-align:end}" (NO RTL override)
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalValues.text_align_end"]

      meta = rule.atomic_classes["text-align"]
      assert meta.class == "xp4054r"
      assert meta.ltr == ".xp4054r{text-align:end}"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end
  end

  describe "modern logical properties - inline properties stay logical" do
    # In StyleX's application-order mode, modern logical inline properties
    # stay as-is (browser handles RTL automatically)

    test "border-inline-color stays as logical property" do
      # StyleX: ".x1v09clb{border-inline-color:0}" with priority 2000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.border_inline_color"
        ]

      meta = rule.atomic_classes["border-inline-color"]
      assert meta.ltr =~ "border-inline-color:red"
      assert meta.rtl == nil
    end

    test "border-inline-start-color stays as logical property" do
      # StyleX: ".x1t19a1o{border-inline-start-color:0}" with priority 3000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.border_inline_start_color"
        ]

      meta = rule.atomic_classes["border-inline-start-color"]
      assert meta.ltr =~ "border-inline-start-color:red"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "border-inline-end-color stays as logical property" do
      # StyleX: ".x14mj1wy{border-inline-end-color:0}" with priority 3000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.border_inline_end_color"
        ]

      meta = rule.atomic_classes["border-inline-end-color"]
      assert meta.ltr =~ "border-inline-end-color:red"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "margin-inline stays as logical property" do
      # StyleX: ".xrxpjvj{margin-inline:0}" with priority 2000
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_inline"]

      meta = rule.atomic_classes["margin-inline"]
      assert meta.ltr =~ "margin-inline:10px"
      assert meta.rtl == nil
    end

    test "margin-inline-start stays as logical property" do
      # StyleX: ".x1lziwak{margin-inline-start:0}" with priority 3000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_inline_start"
        ]

      meta = rule.atomic_classes["margin-inline-start"]
      assert meta.ltr =~ "margin-inline-start:10px"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "margin-inline-end stays as logical property" do
      # StyleX: ".x14z9mp{margin-inline-end:0}" with priority 3000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_inline_end"
        ]

      meta = rule.atomic_classes["margin-inline-end"]
      assert meta.ltr =~ "margin-inline-end:10px"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "padding-inline stays as logical property" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.padding_inline"]

      meta = rule.atomic_classes["padding-inline"]
      assert meta.ltr =~ "padding-inline:10px"
      assert meta.rtl == nil
    end

    test "padding-inline-start stays as logical property" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.padding_inline_start"
        ]

      meta = rule.atomic_classes["padding-inline-start"]
      assert meta.ltr =~ "padding-inline-start:10px"
      assert meta.rtl == nil
    end

    test "inset-inline stays as logical property" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.inset_inline"]

      meta = rule.atomic_classes["inset-inline"]
      assert meta.ltr =~ "inset-inline:10px"
      assert meta.rtl == nil
    end

    test "inset-inline-start stays as logical property" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.inset_inline_start"
        ]

      meta = rule.atomic_classes["inset-inline-start"]
      assert meta.ltr =~ "inset-inline-start:10px"
      assert meta.rtl == nil
    end

    test "inset-inline-end stays as logical property" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.inset_inline_end"]

      meta = rule.atomic_classes["inset-inline-end"]
      assert meta.ltr =~ "inset-inline-end:10px"
      assert meta.rtl == nil
    end
  end

  describe "block properties - shorthand stays, longhands convert to physical" do
    test "margin-block stays as logical shorthand" do
      # StyleX: ".x10im51j{margin-block:0}" with priority 2000
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_block"]

      meta = rule.atomic_classes["margin-block"]
      assert meta.ltr =~ "margin-block:10px"
      assert meta.rtl == nil
    end

    test "margin-block-start becomes margin-top (physical)" do
      # StyleX: ".xdj266r{margin-top:0}" with priority 4000
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_block_start"
        ]

      meta = rule.atomic_classes["margin-top"]
      assert meta.ltr =~ "margin-top:10px"
      assert meta.rtl == nil
      assert meta.priority == 4000
    end

    test "margin-block-end becomes margin-bottom (physical)" do
      # StyleX: ".xat24cr{margin-bottom:0}" with priority 4000
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_block_end"]

      meta = rule.atomic_classes["margin-bottom"]
      assert meta.ltr =~ "margin-bottom:10px"
      assert meta.rtl == nil
      assert meta.priority == 4000
    end
  end

  describe "priority levels" do
    # StyleX priority levels for logical properties:
    # - Shorthand of shorthands (margin, padding): 1000
    # - Shorthand of longhands (margin-inline, margin-block): 2000
    # - Logical longhands (margin-inline-start): 3000
    # - Physical longhands (margin-top, margin-left): 4000

    test "margin-inline has shorthand priority" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_inline"]

      # margin-inline is a shorthand -> priority 1000 or 2000
      assert rule.atomic_classes["margin-inline"].priority in [1000, 2000]
    end

    test "margin-inline-start has logical longhand priority (3000)" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_inline_start"
        ]

      assert rule.atomic_classes["margin-inline-start"].priority == 3000
    end

    test "margin-block-start becomes margin-top with physical priority (4000)" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.LogicalPropertiesTest.LogicalPropertiesModern.margin_block_start"
        ]

      assert rule.atomic_classes["margin-top"].priority == 4000
    end
  end
end
