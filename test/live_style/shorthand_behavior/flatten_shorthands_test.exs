defmodule LiveStyle.ShorthandBehavior.FlattenShorthandsTest do
  @moduledoc """
  Tests for the FlattenShorthands behavior functionality.

  This tests the multi-value parsing that converts shorthand properties like
  `margin: "10px 20px"` into individual longhand properties like
  `margin_top: "10px", margin_right: "20px", margin_bottom: "10px", margin_left: "20px"`.

  These tests cover:
  1. 4-value pattern (box model: top, right, bottom, left)
  2. 2-value pattern (first, second)
  3. border-radius pattern (with slash syntax support)
  4. list-style pattern (special parsing for type/position/image)

  The tests call `LiveStyle.ShorthandBehavior.FlattenShorthands.expand/2` directly.
  """

  use ExUnit.Case, async: true

  # Test via the FlattenShorthands behavior directly
  alias LiveStyle.ShorthandBehavior.FlattenShorthands

  # ==========================================================================
  # 4-Value Pattern Tests (Box Model: top, right, bottom, left)
  # ==========================================================================

  describe "margin flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("margin", "10px")

      assert {:margin_top, "10px"} in result
      assert {:margin_right, "10px"} in result
      assert {:margin_bottom, "10px"} in result
      assert {:margin_left, "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand("margin", "10px 20px")

      assert {:margin_top, "10px"} in result
      assert {:margin_right, "20px"} in result
      assert {:margin_bottom, "10px"} in result
      assert {:margin_left, "20px"} in result
    end

    test "three values: top horizontal bottom" do
      result = FlattenShorthands.expand("margin", "10px 20px 30px")

      assert {:margin_top, "10px"} in result
      assert {:margin_right, "20px"} in result
      assert {:margin_bottom, "30px"} in result
      assert {:margin_left, "20px"} in result
    end

    test "four values: top right bottom left" do
      result = FlattenShorthands.expand("margin", "10px 20px 30px 40px")

      assert {:margin_top, "10px"} in result
      assert {:margin_right, "20px"} in result
      assert {:margin_bottom, "30px"} in result
      assert {:margin_left, "40px"} in result
    end

    test "handles auto value" do
      result = FlattenShorthands.expand("margin", "auto")

      assert {:margin_top, "auto"} in result
      assert {:margin_right, "auto"} in result
      assert {:margin_bottom, "auto"} in result
      assert {:margin_left, "auto"} in result
    end

    test "handles mixed units" do
      result = FlattenShorthands.expand("margin", "1rem 10px 2em 5%")

      assert {:margin_top, "1rem"} in result
      assert {:margin_right, "10px"} in result
      assert {:margin_bottom, "2em"} in result
      assert {:margin_left, "5%"} in result
    end

    test "handles calc() values" do
      result = FlattenShorthands.expand("margin", "calc(100% - 20px) 10px")

      assert {:margin_top, "calc(100% - 20px)"} in result
      assert {:margin_right, "10px"} in result
      assert {:margin_bottom, "calc(100% - 20px)"} in result
      assert {:margin_left, "10px"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand("margin", "10px 20px !important")

      assert {:margin_top, "10px !important"} in result
      assert {:margin_right, "20px !important"} in result
      assert {:margin_bottom, "10px !important"} in result
      assert {:margin_left, "20px !important"} in result
    end
  end

  describe "padding flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("padding", "10px")

      assert {:padding_top, "10px"} in result
      assert {:padding_right, "10px"} in result
      assert {:padding_bottom, "10px"} in result
      assert {:padding_left, "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand("padding", "10px 20px")

      assert {:padding_top, "10px"} in result
      assert {:padding_right, "20px"} in result
      assert {:padding_bottom, "10px"} in result
      assert {:padding_left, "20px"} in result
    end

    test "three values: top horizontal bottom" do
      result = FlattenShorthands.expand("padding", "5px 10px 15px")

      assert {:padding_top, "5px"} in result
      assert {:padding_right, "10px"} in result
      assert {:padding_bottom, "15px"} in result
      assert {:padding_left, "10px"} in result
    end

    test "four values: top right bottom left" do
      result = FlattenShorthands.expand("padding", "5px 10px 15px 20px")

      assert {:padding_top, "5px"} in result
      assert {:padding_right, "10px"} in result
      assert {:padding_bottom, "15px"} in result
      assert {:padding_left, "20px"} in result
    end
  end

  describe "border-width flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("border-width", "1px")

      assert {:border_top_width, "1px"} in result
      assert {:border_right_width, "1px"} in result
      assert {:border_bottom_width, "1px"} in result
      assert {:border_left_width, "1px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand("border-width", "1px 2px")

      assert {:border_top_width, "1px"} in result
      assert {:border_right_width, "2px"} in result
      assert {:border_bottom_width, "1px"} in result
      assert {:border_left_width, "2px"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand("border-width", "1px 2px 3px 4px")

      assert {:border_top_width, "1px"} in result
      assert {:border_right_width, "2px"} in result
      assert {:border_bottom_width, "3px"} in result
      assert {:border_left_width, "4px"} in result
    end
  end

  describe "border-style flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("border-style", "solid")

      assert {:border_top_style, "solid"} in result
      assert {:border_right_style, "solid"} in result
      assert {:border_bottom_style, "solid"} in result
      assert {:border_left_style, "solid"} in result
    end

    test "two values" do
      result = FlattenShorthands.expand("border-style", "solid dashed")

      assert {:border_top_style, "solid"} in result
      assert {:border_right_style, "dashed"} in result
      assert {:border_bottom_style, "solid"} in result
      assert {:border_left_style, "dashed"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand("border-style", "solid dashed dotted double")

      assert {:border_top_style, "solid"} in result
      assert {:border_right_style, "dashed"} in result
      assert {:border_bottom_style, "dotted"} in result
      assert {:border_left_style, "double"} in result
    end
  end

  describe "border-color flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("border-color", "red")

      assert {:border_top_color, "red"} in result
      assert {:border_right_color, "red"} in result
      assert {:border_bottom_color, "red"} in result
      assert {:border_left_color, "red"} in result
    end

    test "two values" do
      result = FlattenShorthands.expand("border-color", "red blue")

      assert {:border_top_color, "red"} in result
      assert {:border_right_color, "blue"} in result
      assert {:border_bottom_color, "red"} in result
      assert {:border_left_color, "blue"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand("border-color", "red green blue yellow")

      assert {:border_top_color, "red"} in result
      assert {:border_right_color, "green"} in result
      assert {:border_bottom_color, "blue"} in result
      assert {:border_left_color, "yellow"} in result
    end

    test "handles rgb() values" do
      result = FlattenShorthands.expand("border-color", "rgb(255, 0, 0) rgb(0, 255, 0)")

      assert {:border_top_color, "rgb(255, 0, 0)"} in result
      assert {:border_right_color, "rgb(0, 255, 0)"} in result
      assert {:border_bottom_color, "rgb(255, 0, 0)"} in result
      assert {:border_left_color, "rgb(0, 255, 0)"} in result
    end
  end

  describe "inset flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand("inset", "10px")

      assert {:top, "10px"} in result
      assert {:right, "10px"} in result
      assert {:bottom, "10px"} in result
      assert {:left, "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand("inset", "10px 20px")

      assert {:top, "10px"} in result
      assert {:right, "20px"} in result
      assert {:bottom, "10px"} in result
      assert {:left, "20px"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand("inset", "0 10px 20px 30px")

      assert {:top, "0"} in result
      assert {:right, "10px"} in result
      assert {:bottom, "20px"} in result
      assert {:left, "30px"} in result
    end
  end

  # ==========================================================================
  # 2-Value Pattern Tests (first, second)
  # ==========================================================================

  describe "gap flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("gap", "10px")

      assert {:row_gap, "10px"} in result
      assert {:column_gap, "10px"} in result
    end

    test "two values: row column" do
      result = FlattenShorthands.expand("gap", "10px 20px")

      assert {:row_gap, "10px"} in result
      assert {:column_gap, "20px"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand("gap", "10px 20px !important")

      assert {:row_gap, "10px !important"} in result
      assert {:column_gap, "20px !important"} in result
    end
  end

  describe "overflow flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("overflow", "hidden")

      assert {:overflow_x, "hidden"} in result
      assert {:overflow_y, "hidden"} in result
    end

    test "two values: x y" do
      result = FlattenShorthands.expand("overflow", "hidden scroll")

      assert {:overflow_x, "hidden"} in result
      assert {:overflow_y, "scroll"} in result
    end

    test "auto values" do
      result = FlattenShorthands.expand("overflow", "auto")

      assert {:overflow_x, "auto"} in result
      assert {:overflow_y, "auto"} in result
    end
  end

  describe "margin-block flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("margin-block", "10px")

      assert {:margin_top, "10px"} in result
      assert {:margin_bottom, "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand("margin-block", "10px 20px")

      assert {:margin_top, "10px"} in result
      assert {:margin_bottom, "20px"} in result
    end
  end

  describe "margin-inline flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("margin-inline", "10px")

      assert {:margin_left, "10px"} in result
      assert {:margin_right, "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand("margin-inline", "10px 20px")

      assert {:margin_left, "10px"} in result
      assert {:margin_right, "20px"} in result
    end
  end

  describe "padding-block flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("padding-block", "10px")

      assert {:padding_top, "10px"} in result
      assert {:padding_bottom, "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand("padding-block", "10px 20px")

      assert {:padding_top, "10px"} in result
      assert {:padding_bottom, "20px"} in result
    end
  end

  describe "padding-inline flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand("padding-inline", "10px")

      assert {:padding_left, "10px"} in result
      assert {:padding_right, "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand("padding-inline", "10px 20px")

      assert {:padding_left, "10px"} in result
      assert {:padding_right, "20px"} in result
    end
  end

  # ==========================================================================
  # Border Radius Pattern Tests (with slash syntax support)
  # ==========================================================================

  describe "border-radius flatten_shorthands (border-radius pattern)" do
    test "single value applies to all corners" do
      result = FlattenShorthands.expand("border-radius", "4px")

      assert {:border_top_left_radius, "4px"} in result
      assert {:border_top_right_radius, "4px"} in result
      assert {:border_bottom_right_radius, "4px"} in result
      assert {:border_bottom_left_radius, "4px"} in result
    end

    test "two values: top-left/bottom-right top-right/bottom-left" do
      result = FlattenShorthands.expand("border-radius", "4px 8px")

      assert {:border_top_left_radius, "4px"} in result
      assert {:border_top_right_radius, "8px"} in result
      assert {:border_bottom_right_radius, "4px"} in result
      assert {:border_bottom_left_radius, "8px"} in result
    end

    test "three values: top-left top-right/bottom-left bottom-right" do
      result = FlattenShorthands.expand("border-radius", "4px 8px 12px")

      assert {:border_top_left_radius, "4px"} in result
      assert {:border_top_right_radius, "8px"} in result
      assert {:border_bottom_right_radius, "12px"} in result
      assert {:border_bottom_left_radius, "8px"} in result
    end

    test "four values: top-left top-right bottom-right bottom-left" do
      result = FlattenShorthands.expand("border-radius", "4px 8px 12px 16px")

      assert {:border_top_left_radius, "4px"} in result
      assert {:border_top_right_radius, "8px"} in result
      assert {:border_bottom_right_radius, "12px"} in result
      assert {:border_bottom_left_radius, "16px"} in result
    end

    test "slash syntax for elliptical corners - single value each side" do
      result = FlattenShorthands.expand("border-radius", "10px / 20px")

      assert {:border_top_left_radius, "10px 20px"} in result
      assert {:border_top_right_radius, "10px 20px"} in result
      assert {:border_bottom_right_radius, "10px 20px"} in result
      assert {:border_bottom_left_radius, "10px 20px"} in result
    end

    test "slash syntax with different horizontal values" do
      result = FlattenShorthands.expand("border-radius", "10px 20px / 30px")

      assert {:border_top_left_radius, "10px 30px"} in result
      assert {:border_top_right_radius, "20px 30px"} in result
      assert {:border_bottom_right_radius, "10px 30px"} in result
      assert {:border_bottom_left_radius, "20px 30px"} in result
    end

    test "slash syntax with different vertical values" do
      result = FlattenShorthands.expand("border-radius", "10px / 20px 30px")

      assert {:border_top_left_radius, "10px 20px"} in result
      assert {:border_top_right_radius, "10px 30px"} in result
      assert {:border_bottom_right_radius, "10px 20px"} in result
      assert {:border_bottom_left_radius, "10px 30px"} in result
    end

    test "slash syntax with four values each side" do
      result = FlattenShorthands.expand("border-radius", "1px 2px 3px 4px / 5px 6px 7px 8px")

      assert {:border_top_left_radius, "1px 5px"} in result
      assert {:border_top_right_radius, "2px 6px"} in result
      assert {:border_bottom_right_radius, "3px 7px"} in result
      assert {:border_bottom_left_radius, "4px 8px"} in result
    end

    test "slash syntax with same h/v values collapses to single value" do
      result = FlattenShorthands.expand("border-radius", "10px / 10px")

      # When h and v are the same, should collapse to single value
      assert {:border_top_left_radius, "10px"} in result
      assert {:border_top_right_radius, "10px"} in result
      assert {:border_bottom_right_radius, "10px"} in result
      assert {:border_bottom_left_radius, "10px"} in result
    end

    test "handles percentage values" do
      result = FlattenShorthands.expand("border-radius", "50%")

      assert {:border_top_left_radius, "50%"} in result
      assert {:border_top_right_radius, "50%"} in result
      assert {:border_bottom_right_radius, "50%"} in result
      assert {:border_bottom_left_radius, "50%"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand("border-radius", "4px 8px !important")

      assert {:border_top_left_radius, "4px !important"} in result
      assert {:border_top_right_radius, "8px !important"} in result
      assert {:border_bottom_right_radius, "4px !important"} in result
      assert {:border_bottom_left_radius, "8px !important"} in result
    end
  end

  # ==========================================================================
  # List Style Pattern Tests
  # ==========================================================================

  describe "list-style flatten_shorthands (list-style pattern)" do
    test "type only" do
      result = FlattenShorthands.expand("list-style", "disc")

      assert {:list_style_type, "disc"} in result
    end

    test "position only" do
      result = FlattenShorthands.expand("list-style", "inside")

      assert {:list_style_position, "inside"} in result
    end

    test "type and position" do
      result = FlattenShorthands.expand("list-style", "disc inside")

      assert {:list_style_type, "disc"} in result
      assert {:list_style_position, "inside"} in result
    end

    test "type and position (reversed order)" do
      result = FlattenShorthands.expand("list-style", "outside square")

      assert {:list_style_type, "square"} in result
      assert {:list_style_position, "outside"} in result
    end

    test "none value as image" do
      result = FlattenShorthands.expand("list-style", "none")

      assert {:list_style_image, "none"} in result
    end

    test "url() image" do
      result = FlattenShorthands.expand("list-style", "url(bullet.png)")

      assert {:list_style_image, "url(bullet.png)"} in result
    end

    test "type, position, and image" do
      result = FlattenShorthands.expand("list-style", "disc inside url(bullet.png)")

      assert {:list_style_type, "disc"} in result
      assert {:list_style_position, "inside"} in result
      assert {:list_style_image, "url(bullet.png)"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand("list-style", "disc inside !important")

      assert {:list_style_type, "disc !important"} in result
      assert {:list_style_position, "inside !important"} in result
    end
  end

  # ==========================================================================
  # Passthrough Tests (properties without flatten_shorthands support)
  # ==========================================================================

  describe "passthrough for unsupported properties" do
    test "color passes through unchanged" do
      result = FlattenShorthands.expand("color", "red")

      assert result == [{:color, "red"}]
    end

    test "display passes through unchanged" do
      result = FlattenShorthands.expand("display", "flex")

      assert result == [{:display, "flex"}]
    end

    test "width passes through unchanged" do
      result = FlattenShorthands.expand("width", "100px")

      assert result == [{:width, "100px"}]
    end

    test "custom property passes through unchanged" do
      result = FlattenShorthands.expand("--my-var", "10px")

      # Custom properties get converted to atoms with underscores
      assert result == [{:__my_var, "10px"}]
    end
  end

  # ==========================================================================
  # Edge Cases and Complex Values
  # ==========================================================================

  describe "edge cases" do
    test "handles var() in margin" do
      result = FlattenShorthands.expand("margin", "var(--spacing)")

      assert {:margin_top, "var(--spacing)"} in result
      assert {:margin_right, "var(--spacing)"} in result
      assert {:margin_bottom, "var(--spacing)"} in result
      assert {:margin_left, "var(--spacing)"} in result
    end

    test "handles var() with fallback" do
      result = FlattenShorthands.expand("margin", "var(--spacing, 10px)")

      assert {:margin_top, "var(--spacing, 10px)"} in result
      assert {:margin_right, "var(--spacing, 10px)"} in result
    end

    test "handles clamp() in gap" do
      result = FlattenShorthands.expand("gap", "clamp(10px, 5vw, 50px)")

      assert {:row_gap, "clamp(10px, 5vw, 50px)"} in result
      assert {:column_gap, "clamp(10px, 5vw, 50px)"} in result
    end

    test "handles negative values in margin" do
      result = FlattenShorthands.expand("margin", "-10px -20px")

      assert {:margin_top, "-10px"} in result
      assert {:margin_right, "-20px"} in result
      assert {:margin_bottom, "-10px"} in result
      assert {:margin_left, "-20px"} in result
    end

    test "handles 0 values" do
      result = FlattenShorthands.expand("padding", "0 10px 0 0")

      assert {:padding_top, "0"} in result
      assert {:padding_right, "10px"} in result
      assert {:padding_bottom, "0"} in result
      assert {:padding_left, "0"} in result
    end

    test "handles inherit value" do
      result = FlattenShorthands.expand("margin", "inherit")

      assert {:margin_top, "inherit"} in result
      assert {:margin_right, "inherit"} in result
      assert {:margin_bottom, "inherit"} in result
      assert {:margin_left, "inherit"} in result
    end

    test "handles initial value" do
      result = FlattenShorthands.expand("padding", "initial")

      assert {:padding_top, "initial"} in result
      assert {:padding_right, "initial"} in result
      assert {:padding_bottom, "initial"} in result
      assert {:padding_left, "initial"} in result
    end

    test "handles unset value" do
      result = FlattenShorthands.expand("gap", "unset")

      assert {:row_gap, "unset"} in result
      assert {:column_gap, "unset"} in result
    end
  end
end
