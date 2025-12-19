defmodule LiveStyle.ShorthandBehavior.AcceptShorthandsTest do
  @moduledoc """
  Tests for the AcceptShorthands behavior.

  These tests verify the AcceptShorthands behavior:
  1. The expand/2 function returns the correct property list
  2. The value is correctly assigned to the primary property
  3. Related properties are correctly reset to nil for cascade control
     (though nils are filtered out in the final result)

  The AcceptShorthands behavior keeps shorthand properties intact while
  resetting conflicting longhands to nil for deterministic cascade behavior.
  """

  use ExUnit.Case, async: true

  alias LiveStyle.ShorthandBehavior.AcceptShorthands

  # ==========================================================================
  # Margin Expansions
  # ==========================================================================

  describe "margin expansions" do
    test "expand margin returns margin with value" do
      result = AcceptShorthands.expand("margin", "10px")

      # AcceptShorthands filters out nils, so we only get the shorthand
      assert {:margin, "10px"} in result
    end

    test "expand margin-horizontal sets margin-inline" do
      result = AcceptShorthands.expand("margin-horizontal", "10px")

      assert {:margin_inline, "10px"} in result
    end

    test "expand margin-vertical sets margin-block" do
      result = AcceptShorthands.expand("margin-vertical", "10px")

      assert {:margin_block, "10px"} in result
    end

    test "expand margin-start sets margin-inline-start" do
      result = AcceptShorthands.expand("margin-start", "10px")

      assert {:margin_inline_start, "10px"} in result
    end

    test "expand margin-end sets margin-inline-end" do
      result = AcceptShorthands.expand("margin-end", "10px")

      assert {:margin_inline_end, "10px"} in result
    end

    test "expand margin-left sets margin-left" do
      result = AcceptShorthands.expand("margin-left", "10px")

      assert {:margin_left, "10px"} in result
    end

    test "expand margin-right sets margin-right" do
      result = AcceptShorthands.expand("margin-right", "10px")

      assert {:margin_right, "10px"} in result
    end

    test "expand margin-block-start maps to margin-top" do
      result = AcceptShorthands.expand("margin-block-start", "10px")
      assert result == [{:margin_top, "10px"}]
    end

    test "expand margin-block-end maps to margin-bottom" do
      result = AcceptShorthands.expand("margin-block-end", "10px")
      assert result == [{:margin_bottom, "10px"}]
    end
  end

  # ==========================================================================
  # Padding Expansions
  # ==========================================================================

  describe "padding expansions" do
    test "expand padding returns padding with value" do
      result = AcceptShorthands.expand("padding", "10px")

      assert {:padding, "10px"} in result
    end

    test "expand padding-horizontal sets padding-inline" do
      result = AcceptShorthands.expand("padding-horizontal", "10px")

      assert {:padding_inline, "10px"} in result
    end

    test "expand padding-vertical sets padding-block" do
      result = AcceptShorthands.expand("padding-vertical", "10px")

      assert {:padding_block, "10px"} in result
    end

    test "expand padding-block-start maps to padding-top" do
      result = AcceptShorthands.expand("padding-block-start", "10px")
      assert result == [{:padding_top, "10px"}]
    end

    test "expand padding-block-end maps to padding-bottom" do
      result = AcceptShorthands.expand("padding-block-end", "10px")
      assert result == [{:padding_bottom, "10px"}]
    end
  end

  # ==========================================================================
  # Gap Expansions
  # ==========================================================================

  describe "gap expansions" do
    test "expand gap sets gap" do
      result = AcceptShorthands.expand("gap", "10px")

      assert {:gap, "10px"} in result
    end

    test "expand grid-row-gap maps to row-gap" do
      result = AcceptShorthands.expand("grid-row-gap", "10px")
      assert result == [{:row_gap, "10px"}]
    end

    test "expand grid-column-gap maps to column-gap" do
      result = AcceptShorthands.expand("grid-column-gap", "10px")
      assert result == [{:column_gap, "10px"}]
    end
  end

  # ==========================================================================
  # Overflow Expansions
  # ==========================================================================

  describe "overflow expansions" do
    test "expand overflow sets overflow" do
      result = AcceptShorthands.expand("overflow", "hidden")

      assert {:overflow, "hidden"} in result
    end

    test "expand overflow-block maps to overflow-y" do
      result = AcceptShorthands.expand("overflow-block", "scroll")
      assert result == [{:overflow_y, "scroll"}]
    end

    test "expand overflow-inline maps to overflow-x" do
      result = AcceptShorthands.expand("overflow-inline", "auto")
      assert result == [{:overflow_x, "auto"}]
    end
  end

  # ==========================================================================
  # Border Expansions
  # ==========================================================================

  describe "border expansions" do
    test "expand border returns border with value" do
      result = AcceptShorthands.expand("border", "1px solid red")

      assert {:border, "1px solid red"} in result
    end

    test "expand border-color returns border-color with value" do
      result = AcceptShorthands.expand("border-color", "red")

      assert {:border_color, "red"} in result
    end

    test "expand border-top returns border-top with value" do
      result = AcceptShorthands.expand("border-top", "1px solid red")

      assert {:border_top, "1px solid red"} in result
    end

    test "expand border-left returns border-left with value" do
      result = AcceptShorthands.expand("border-left", "1px solid red")

      assert {:border_left, "1px solid red"} in result
    end

    test "expand border-inline-start returns border-inline-start with value" do
      result = AcceptShorthands.expand("border-inline-start", "1px solid red")

      assert {:border_inline_start, "1px solid red"} in result
    end
  end

  # ==========================================================================
  # Border Width Expansions
  # ==========================================================================

  describe "border width expansions" do
    test "expand border-width returns border-width with value" do
      result = AcceptShorthands.expand("border-width", "1px")

      assert {:border_width, "1px"} in result
    end

    test "expand border-block-width returns border-block-width with value" do
      result = AcceptShorthands.expand("border-block-width", "1px")

      assert {:border_block_width, "1px"} in result
    end

    test "expand border-inline-start-width returns border-inline-start-width with value" do
      result = AcceptShorthands.expand("border-inline-start-width", "1px")

      assert {:border_inline_start_width, "1px"} in result
    end

    test "expand border-left-width returns border-left-width with value" do
      result = AcceptShorthands.expand("border-left-width", "1px")

      assert {:border_left_width, "1px"} in result
    end
  end

  # ==========================================================================
  # Border Radius Expansions
  # ==========================================================================

  describe "border radius expansions" do
    test "expand border-radius returns border-radius with value" do
      result = AcceptShorthands.expand("border-radius", "4px")

      assert {:border_radius, "4px"} in result
    end

    test "expand border-top-start-radius maps to logical radius" do
      result = AcceptShorthands.expand("border-top-start-radius", "4px")
      assert result == [{:border_start_start_radius, "4px"}]
    end

    test "expand border-start-start-radius returns border-start-start-radius with value" do
      result = AcceptShorthands.expand("border-start-start-radius", "4px")

      assert {:border_start_start_radius, "4px"} in result
    end

    test "expand border-top-left-radius returns border-top-left-radius with value" do
      result = AcceptShorthands.expand("border-top-left-radius", "4px")

      assert {:border_top_left_radius, "4px"} in result
    end
  end

  # ==========================================================================
  # Inset Expansions
  # ==========================================================================

  describe "inset expansions" do
    test "expand inset returns inset with value" do
      result = AcceptShorthands.expand("inset", "10px")

      assert {:inset, "10px"} in result
    end

    test "expand inset-inline returns inset-inline with value" do
      result = AcceptShorthands.expand("inset-inline", "10px")

      assert {:inset_inline, "10px"} in result
    end

    test "expand inset-block returns inset-block with value" do
      result = AcceptShorthands.expand("inset-block", "10px")

      assert {:inset_block, "10px"} in result
    end

    test "expand start sets inset-inline-start" do
      result = AcceptShorthands.expand("start", "10px")

      assert {:inset_inline_start, "10px"} in result
    end

    test "expand left returns left with value" do
      result = AcceptShorthands.expand("left", "10px")

      assert {:left, "10px"} in result
    end
  end

  # ==========================================================================
  # Logical Size Expansions
  # ==========================================================================

  describe "logical size expansions" do
    test "expand block-size maps to height" do
      result = AcceptShorthands.expand("block-size", "100px")
      assert result == [{:height, "100px"}]
    end

    test "expand inline-size maps to width" do
      result = AcceptShorthands.expand("inline-size", "100px")
      assert result == [{:width, "100px"}]
    end

    test "expand min-block-size maps to min-height" do
      result = AcceptShorthands.expand("min-block-size", "50px")
      assert result == [{:min_height, "50px"}]
    end

    test "expand max-inline-size maps to max-width" do
      result = AcceptShorthands.expand("max-inline-size", "500px")
      assert result == [{:max_width, "500px"}]
    end
  end

  # ==========================================================================
  # Flex Expansions
  # ==========================================================================

  describe "flex expansions" do
    test "expand flex returns flex with value" do
      result = AcceptShorthands.expand("flex", "1 1 auto")

      assert {:flex, "1 1 auto"} in result
    end

    test "expand flex-flow returns flex-flow with value" do
      result = AcceptShorthands.expand("flex-flow", "row wrap")

      assert {:flex_flow, "row wrap"} in result
    end
  end

  # ==========================================================================
  # Grid Expansions
  # ==========================================================================

  describe "grid expansions" do
    test "expand grid returns grid with value" do
      result = AcceptShorthands.expand("grid", "auto / 1fr 1fr")

      assert {:grid, "auto / 1fr 1fr"} in result
    end

    test "expand grid-area returns grid-area with value" do
      result = AcceptShorthands.expand("grid-area", "header")

      assert {:grid_area, "header"} in result
    end
  end

  # ==========================================================================
  # Animation & Transition Expansions
  # ==========================================================================

  describe "animation expansions" do
    test "expand animation returns animation with value" do
      result = AcceptShorthands.expand("animation", "spin 1s linear infinite")

      assert {:animation, "spin 1s linear infinite"} in result
    end

    test "expand transition returns transition with value" do
      result = AcceptShorthands.expand("transition", "all 0.3s ease")

      assert {:transition, "all 0.3s ease"} in result
    end
  end

  # ==========================================================================
  # Background Expansions
  # ==========================================================================

  describe "background expansions" do
    test "expand background returns background with value" do
      result = AcceptShorthands.expand("background", "red url(bg.png) center/cover")

      assert {:background, "red url(bg.png) center/cover"} in result
    end

    test "expand background-position returns background-position with value" do
      result = AcceptShorthands.expand("background-position", "center top")

      assert {:background_position, "center top"} in result
    end
  end

  # ==========================================================================
  # Scroll Margin/Padding Expansions
  # ==========================================================================

  describe "scroll margin expansions" do
    test "expand scroll-margin returns scroll-margin with value" do
      result = AcceptShorthands.expand("scroll-margin", "10px")

      assert {:scroll_margin, "10px"} in result
    end

    test "expand scroll-margin-inline-start returns scroll-margin-inline-start with value" do
      result = AcceptShorthands.expand("scroll-margin-inline-start", "10px")

      assert {:scroll_margin_inline_start, "10px"} in result
    end
  end

  # ==========================================================================
  # Place Expansions
  # ==========================================================================

  describe "place expansions" do
    test "expand place-content returns place-content with value" do
      result = AcceptShorthands.expand("place-content", "center")

      assert {:place_content, "center"} in result
    end

    test "expand place-items returns place-items with value" do
      result = AcceptShorthands.expand("place-items", "center")

      assert {:place_items, "center"} in result
    end

    test "expand place-self returns place-self with value" do
      result = AcceptShorthands.expand("place-self", "start")

      assert {:place_self, "start"} in result
    end
  end

  # ==========================================================================
  # Complex Expansions (require runtime parsing)
  # ==========================================================================

  describe "complex expansions (runtime parsing)" do
    test "expand overscroll-behavior parses two-value input" do
      result = AcceptShorthands.expand("overscroll-behavior", "auto contain")

      assert {:overscroll_behavior_x, "auto"} in result
      assert {:overscroll_behavior_y, "contain"} in result
    end

    test "expand overscroll-behavior with single value applies to both" do
      result = AcceptShorthands.expand("overscroll-behavior", "none")

      assert {:overscroll_behavior_x, "none"} in result
      assert {:overscroll_behavior_y, "none"} in result
    end

    test "expand contain-intrinsic-size parses two-value input" do
      result = AcceptShorthands.expand("contain-intrinsic-size", "100px 200px")

      assert {:contain_intrinsic_width, "100px"} in result
      assert {:contain_intrinsic_height, "200px"} in result
    end

    test "expand contain-intrinsic-size with single value applies to both" do
      result = AcceptShorthands.expand("contain-intrinsic-size", "100px")

      assert {:contain_intrinsic_width, "100px"} in result
      assert {:contain_intrinsic_height, "100px"} in result
    end

    test "expand contain-intrinsic-size handles auto prefix" do
      result = AcceptShorthands.expand("contain-intrinsic-size", "auto 100px 200px")

      assert {:contain_intrinsic_width, "auto 100px"} in result
      assert {:contain_intrinsic_height, "200px"} in result
    end
  end

  # ==========================================================================
  # Other Expansions
  # ==========================================================================

  describe "other expansions" do
    test "expand text-decoration returns text-decoration with value" do
      result = AcceptShorthands.expand("text-decoration", "underline red wavy")

      assert {:text_decoration, "underline red wavy"} in result
    end

    test "expand outline returns outline with value" do
      result = AcceptShorthands.expand("outline", "1px solid blue")

      assert {:outline, "1px solid blue"} in result
    end

    test "expand font returns font with value" do
      result = AcceptShorthands.expand("font", "16px/1.5 Arial")

      assert {:font, "16px/1.5 Arial"} in result
    end

    test "expand columns returns columns with value" do
      result = AcceptShorthands.expand("columns", "3 200px")

      assert {:columns, "3 200px"} in result
    end

    test "expand list-style returns list-style with value" do
      result = AcceptShorthands.expand("list-style", "disc inside")

      assert {:list_style, "disc inside"} in result
    end
  end

  # ==========================================================================
  # Non-Shorthand Properties
  # ==========================================================================

  describe "non-shorthand properties" do
    test "expand color passes through unchanged" do
      result = AcceptShorthands.expand("color", "red")
      assert result == [{:color, "red"}]
    end

    test "expand display passes through unchanged" do
      result = AcceptShorthands.expand("display", "flex")
      assert result == [{:display, "flex"}]
    end

    test "expand width passes through unchanged" do
      result = AcceptShorthands.expand("width", "100px")
      assert result == [{:width, "100px"}]
    end
  end
end
