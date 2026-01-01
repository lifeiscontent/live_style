defmodule LiveStyle.ShorthandBehavior.FlattenShorthandsTest do
  @moduledoc """
  Tests for the FlattenShorthands behavior functionality.

  This tests the multi-value parsing that converts shorthand properties like
  `margin: "10px 20px"` into individual longhand properties like
  `margin-top: "10px", margin-right: "20px", margin-bottom: "10px", margin-left: "20px"`.

  These tests cover:
  1. 4-value pattern (box model: top, right, bottom, left)
  2. 2-value pattern (first, second)
  3. border-radius pattern (with slash syntax support)
  4. list-style pattern (special parsing for type/position/image)

  The tests call `LiveStyle.ShorthandBehavior.FlattenShorthands.expand_declaration/3` directly.
  """

  use LiveStyle.TestCase

  # Test via the FlattenShorthands behavior directly
  alias LiveStyle.ShorthandBehavior.FlattenShorthands

  # ==========================================================================
  # 4-Value Pattern Tests (Box Model: top, right, bottom, left)
  # ==========================================================================

  describe "margin flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("margin", "10px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-right", "10px"} in result
      assert {"margin-bottom", "10px"} in result
      assert {"margin-left", "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand_declaration("margin", "10px 20px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-right", "20px"} in result
      assert {"margin-bottom", "10px"} in result
      assert {"margin-left", "20px"} in result
    end

    test "three values: top horizontal bottom" do
      result = FlattenShorthands.expand_declaration("margin", "10px 20px 30px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-right", "20px"} in result
      assert {"margin-bottom", "30px"} in result
      assert {"margin-left", "20px"} in result
    end

    test "four values: top right bottom left" do
      result = FlattenShorthands.expand_declaration("margin", "10px 20px 30px 40px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-right", "20px"} in result
      assert {"margin-bottom", "30px"} in result
      assert {"margin-left", "40px"} in result
    end

    test "handles auto value" do
      result = FlattenShorthands.expand_declaration("margin", "auto", %{})

      assert {"margin-top", "auto"} in result
      assert {"margin-right", "auto"} in result
      assert {"margin-bottom", "auto"} in result
      assert {"margin-left", "auto"} in result
    end

    test "handles mixed units" do
      result = FlattenShorthands.expand_declaration("margin", "1rem 10px 2em 5%", %{})

      assert {"margin-top", "1rem"} in result
      assert {"margin-right", "10px"} in result
      assert {"margin-bottom", "2em"} in result
      assert {"margin-left", "5%"} in result
    end

    test "handles calc() values" do
      result = FlattenShorthands.expand_declaration("margin", "calc(100% - 20px) 10px", %{})

      assert {"margin-top", "calc(100% - 20px)"} in result
      assert {"margin-right", "10px"} in result
      assert {"margin-bottom", "calc(100% - 20px)"} in result
      assert {"margin-left", "10px"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand_declaration("margin", "10px 20px !important", %{})

      assert {"margin-top", "10px !important"} in result
      assert {"margin-right", "20px !important"} in result
      assert {"margin-bottom", "10px !important"} in result
      assert {"margin-left", "20px !important"} in result
    end
  end

  describe "padding flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("padding", "10px", %{})

      assert {"padding-top", "10px"} in result
      assert {"padding-right", "10px"} in result
      assert {"padding-bottom", "10px"} in result
      assert {"padding-left", "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand_declaration("padding", "10px 20px", %{})

      assert {"padding-top", "10px"} in result
      assert {"padding-right", "20px"} in result
      assert {"padding-bottom", "10px"} in result
      assert {"padding-left", "20px"} in result
    end

    test "three values: top horizontal bottom" do
      result = FlattenShorthands.expand_declaration("padding", "5px 10px 15px", %{})

      assert {"padding-top", "5px"} in result
      assert {"padding-right", "10px"} in result
      assert {"padding-bottom", "15px"} in result
      assert {"padding-left", "10px"} in result
    end

    test "four values: top right bottom left" do
      result = FlattenShorthands.expand_declaration("padding", "5px 10px 15px 20px", %{})

      assert {"padding-top", "5px"} in result
      assert {"padding-right", "10px"} in result
      assert {"padding-bottom", "15px"} in result
      assert {"padding-left", "20px"} in result
    end
  end

  describe "border-width flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("border-width", "1px", %{})

      assert {"border-top-width", "1px"} in result
      assert {"border-right-width", "1px"} in result
      assert {"border-bottom-width", "1px"} in result
      assert {"border-left-width", "1px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand_declaration("border-width", "1px 2px", %{})

      assert {"border-top-width", "1px"} in result
      assert {"border-right-width", "2px"} in result
      assert {"border-bottom-width", "1px"} in result
      assert {"border-left-width", "2px"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand_declaration("border-width", "1px 2px 3px 4px", %{})

      assert {"border-top-width", "1px"} in result
      assert {"border-right-width", "2px"} in result
      assert {"border-bottom-width", "3px"} in result
      assert {"border-left-width", "4px"} in result
    end
  end

  describe "border-style flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("border-style", "solid", %{})

      assert {"border-top-style", "solid"} in result
      assert {"border-right-style", "solid"} in result
      assert {"border-bottom-style", "solid"} in result
      assert {"border-left-style", "solid"} in result
    end

    test "two values" do
      result = FlattenShorthands.expand_declaration("border-style", "solid dashed", %{})

      assert {"border-top-style", "solid"} in result
      assert {"border-right-style", "dashed"} in result
      assert {"border-bottom-style", "solid"} in result
      assert {"border-left-style", "dashed"} in result
    end

    test "four values" do
      result =
        FlattenShorthands.expand_declaration("border-style", "solid dashed dotted double", %{})

      assert {"border-top-style", "solid"} in result
      assert {"border-right-style", "dashed"} in result
      assert {"border-bottom-style", "dotted"} in result
      assert {"border-left-style", "double"} in result
    end
  end

  describe "border-color flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("border-color", "red", %{})

      assert {"border-top-color", "red"} in result
      assert {"border-right-color", "red"} in result
      assert {"border-bottom-color", "red"} in result
      assert {"border-left-color", "red"} in result
    end

    test "two values" do
      result = FlattenShorthands.expand_declaration("border-color", "red blue", %{})

      assert {"border-top-color", "red"} in result
      assert {"border-right-color", "blue"} in result
      assert {"border-bottom-color", "red"} in result
      assert {"border-left-color", "blue"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand_declaration("border-color", "red green blue yellow", %{})

      assert {"border-top-color", "red"} in result
      assert {"border-right-color", "green"} in result
      assert {"border-bottom-color", "blue"} in result
      assert {"border-left-color", "yellow"} in result
    end

    test "handles rgb() values" do
      result =
        FlattenShorthands.expand_declaration("border-color", "rgb(255, 0, 0) rgb(0, 255, 0)", %{})

      assert {"border-top-color", "rgb(255, 0, 0)"} in result
      assert {"border-right-color", "rgb(0, 255, 0)"} in result
      assert {"border-bottom-color", "rgb(255, 0, 0)"} in result
      assert {"border-left-color", "rgb(0, 255, 0)"} in result
    end
  end

  describe "inset flatten_shorthands (4-value pattern)" do
    test "single value applies to all sides" do
      result = FlattenShorthands.expand_declaration("inset", "10px", %{})

      assert {"top", "10px"} in result
      assert {"right", "10px"} in result
      assert {"bottom", "10px"} in result
      assert {"left", "10px"} in result
    end

    test "two values: vertical horizontal" do
      result = FlattenShorthands.expand_declaration("inset", "10px 20px", %{})

      assert {"top", "10px"} in result
      assert {"right", "20px"} in result
      assert {"bottom", "10px"} in result
      assert {"left", "20px"} in result
    end

    test "four values" do
      result = FlattenShorthands.expand_declaration("inset", "0 10px 20px 30px", %{})

      assert {"top", "0"} in result
      assert {"right", "10px"} in result
      assert {"bottom", "20px"} in result
      assert {"left", "30px"} in result
    end
  end

  # ==========================================================================
  # 2-Value Pattern Tests (first, second)
  # ==========================================================================

  describe "gap flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("gap", "10px", %{})

      assert {"row-gap", "10px"} in result
      assert {"column-gap", "10px"} in result
    end

    test "two values: row column" do
      result = FlattenShorthands.expand_declaration("gap", "10px 20px", %{})

      assert {"row-gap", "10px"} in result
      assert {"column-gap", "20px"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand_declaration("gap", "10px 20px !important", %{})

      assert {"row-gap", "10px !important"} in result
      assert {"column-gap", "20px !important"} in result
    end
  end

  describe "overflow flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("overflow", "hidden", %{})

      assert {"overflow-x", "hidden"} in result
      assert {"overflow-y", "hidden"} in result
    end

    test "two values: x y" do
      result = FlattenShorthands.expand_declaration("overflow", "hidden scroll", %{})

      assert {"overflow-x", "hidden"} in result
      assert {"overflow-y", "scroll"} in result
    end

    test "auto values" do
      result = FlattenShorthands.expand_declaration("overflow", "auto", %{})

      assert {"overflow-x", "auto"} in result
      assert {"overflow-y", "auto"} in result
    end
  end

  describe "margin-block flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("margin-block", "10px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-bottom", "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand_declaration("margin-block", "10px 20px", %{})

      assert {"margin-top", "10px"} in result
      assert {"margin-bottom", "20px"} in result
    end
  end

  describe "margin-inline flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("margin-inline", "10px", %{})

      assert {"margin-left", "10px"} in result
      assert {"margin-right", "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand_declaration("margin-inline", "10px 20px", %{})

      assert {"margin-left", "10px"} in result
      assert {"margin-right", "20px"} in result
    end
  end

  describe "padding-block flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("padding-block", "10px", %{})

      assert {"padding-top", "10px"} in result
      assert {"padding-bottom", "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand_declaration("padding-block", "10px 20px", %{})

      assert {"padding-top", "10px"} in result
      assert {"padding-bottom", "20px"} in result
    end
  end

  describe "padding-inline flatten_shorthands (2-value pattern)" do
    test "single value applies to both" do
      result = FlattenShorthands.expand_declaration("padding-inline", "10px", %{})

      assert {"padding-left", "10px"} in result
      assert {"padding-right", "10px"} in result
    end

    test "two values: start end" do
      result = FlattenShorthands.expand_declaration("padding-inline", "10px 20px", %{})

      assert {"padding-left", "10px"} in result
      assert {"padding-right", "20px"} in result
    end
  end

  # ==========================================================================
  # Border Radius Pattern Tests (with slash syntax support)
  # ==========================================================================

  describe "border-radius flatten_shorthands (border-radius pattern)" do
    test "single value applies to all corners" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px", %{})

      assert {"border-top-left-radius", "4px"} in result
      assert {"border-top-right-radius", "4px"} in result
      assert {"border-bottom-right-radius", "4px"} in result
      assert {"border-bottom-left-radius", "4px"} in result
    end

    test "two values: top-left/bottom-right top-right/bottom-left" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px 8px", %{})

      assert {"border-top-left-radius", "4px"} in result
      assert {"border-top-right-radius", "8px"} in result
      assert {"border-bottom-right-radius", "4px"} in result
      assert {"border-bottom-left-radius", "8px"} in result
    end

    test "three values: top-left top-right/bottom-left bottom-right" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px 8px 12px", %{})

      assert {"border-top-left-radius", "4px"} in result
      assert {"border-top-right-radius", "8px"} in result
      assert {"border-bottom-right-radius", "12px"} in result
      assert {"border-bottom-left-radius", "8px"} in result
    end

    test "four values: top-left top-right bottom-right bottom-left" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px 8px 12px 16px", %{})

      assert {"border-top-left-radius", "4px"} in result
      assert {"border-top-right-radius", "8px"} in result
      assert {"border-bottom-right-radius", "12px"} in result
      assert {"border-bottom-left-radius", "16px"} in result
    end

    test "slash syntax for elliptical corners - single value each side" do
      result = FlattenShorthands.expand_declaration("border-radius", "10px / 20px", %{})

      assert {"border-top-left-radius", "10px 20px"} in result
      assert {"border-top-right-radius", "10px 20px"} in result
      assert {"border-bottom-right-radius", "10px 20px"} in result
      assert {"border-bottom-left-radius", "10px 20px"} in result
    end

    test "slash syntax with different horizontal values" do
      result = FlattenShorthands.expand_declaration("border-radius", "10px 20px / 30px", %{})

      assert {"border-top-left-radius", "10px 30px"} in result
      assert {"border-top-right-radius", "20px 30px"} in result
      assert {"border-bottom-right-radius", "10px 30px"} in result
      assert {"border-bottom-left-radius", "20px 30px"} in result
    end

    test "slash syntax with different vertical values" do
      result = FlattenShorthands.expand_declaration("border-radius", "10px / 20px 30px", %{})

      assert {"border-top-left-radius", "10px 20px"} in result
      assert {"border-top-right-radius", "10px 30px"} in result
      assert {"border-bottom-right-radius", "10px 20px"} in result
      assert {"border-bottom-left-radius", "10px 30px"} in result
    end

    test "slash syntax with four values each side" do
      result =
        FlattenShorthands.expand_declaration(
          "border-radius",
          "1px 2px 3px 4px / 5px 6px 7px 8px",
          %{}
        )

      assert {"border-top-left-radius", "1px 5px"} in result
      assert {"border-top-right-radius", "2px 6px"} in result
      assert {"border-bottom-right-radius", "3px 7px"} in result
      assert {"border-bottom-left-radius", "4px 8px"} in result
    end

    test "slash syntax with same h/v values collapses to single value" do
      result = FlattenShorthands.expand_declaration("border-radius", "10px / 10px", %{})

      # When h and v are the same, should collapse to single value
      assert {"border-top-left-radius", "10px"} in result
      assert {"border-top-right-radius", "10px"} in result
      assert {"border-bottom-right-radius", "10px"} in result
      assert {"border-bottom-left-radius", "10px"} in result
    end

    test "handles percentage values" do
      result = FlattenShorthands.expand_declaration("border-radius", "50%", %{})

      assert {"border-top-left-radius", "50%"} in result
      assert {"border-top-right-radius", "50%"} in result
      assert {"border-bottom-right-radius", "50%"} in result
      assert {"border-bottom-left-radius", "50%"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px 8px !important", %{})

      assert {"border-top-left-radius", "4px !important"} in result
      assert {"border-top-right-radius", "8px !important"} in result
      assert {"border-bottom-right-radius", "4px !important"} in result
      assert {"border-bottom-left-radius", "8px !important"} in result
    end
  end

  # ==========================================================================
  # List Style Pattern Tests
  # ==========================================================================

  describe "list-style flatten_shorthands (list-style pattern)" do
    test "type only" do
      result = FlattenShorthands.expand_declaration("list-style", "disc", %{})

      assert {"list-style-type", "disc"} in result
    end

    test "position only" do
      result = FlattenShorthands.expand_declaration("list-style", "inside", %{})

      assert {"list-style-position", "inside"} in result
    end

    test "type and position" do
      result = FlattenShorthands.expand_declaration("list-style", "disc inside", %{})

      assert {"list-style-type", "disc"} in result
      assert {"list-style-position", "inside"} in result
    end

    test "type and position (reversed order)" do
      result = FlattenShorthands.expand_declaration("list-style", "outside square", %{})

      assert {"list-style-type", "square"} in result
      assert {"list-style-position", "outside"} in result
    end

    test "none value as image" do
      result = FlattenShorthands.expand_declaration("list-style", "none", %{})

      assert {"list-style-image", "none"} in result
    end

    test "url() image" do
      result = FlattenShorthands.expand_declaration("list-style", "url(bullet.png)", %{})

      assert {"list-style-image", "url(bullet.png)"} in result
    end

    test "type, position, and image" do
      result =
        FlattenShorthands.expand_declaration("list-style", "disc inside url(bullet.png)", %{})

      assert {"list-style-type", "disc"} in result
      assert {"list-style-position", "inside"} in result
      assert {"list-style-image", "url(bullet.png)"} in result
    end

    test "handles !important" do
      result = FlattenShorthands.expand_declaration("list-style", "disc inside !important", %{})

      assert {"list-style-type", "disc !important"} in result
      assert {"list-style-position", "inside !important"} in result
    end
  end

  # ==========================================================================
  # Passthrough Tests (properties without flatten_shorthands support)
  # ==========================================================================

  describe "passthrough for unsupported properties" do
    test "color passes through unchanged" do
      result = FlattenShorthands.expand_declaration("color", "red", %{})

      assert result == [{"color", "red"}]
    end

    test "display passes through unchanged" do
      result = FlattenShorthands.expand_declaration("display", "flex", %{})

      assert result == [{"display", "flex"}]
    end

    test "width passes through unchanged" do
      result = FlattenShorthands.expand_declaration("width", "100px", %{})

      assert result == [{"width", "100px"}]
    end

    test "custom property passes through unchanged" do
      result = FlattenShorthands.expand_declaration("--my-var", "10px", %{})

      assert result == [{"--my-var", "10px"}]
    end
  end

  # ==========================================================================
  # Edge Cases and Complex Values
  # ==========================================================================

  describe "edge cases" do
    test "handles var() in margin" do
      result = FlattenShorthands.expand_declaration("margin", "var(--spacing)", %{})

      assert {"margin-top", "var(--spacing)"} in result
      assert {"margin-right", "var(--spacing)"} in result
      assert {"margin-bottom", "var(--spacing)"} in result
      assert {"margin-left", "var(--spacing)"} in result
    end

    test "handles var() with fallback" do
      result = FlattenShorthands.expand_declaration("margin", "var(--spacing, 10px)", %{})

      assert {"margin-top", "var(--spacing, 10px)"} in result
      assert {"margin-right", "var(--spacing, 10px)"} in result
    end

    test "handles clamp() in gap" do
      result = FlattenShorthands.expand_declaration("gap", "clamp(10px, 5vw, 50px)", %{})

      assert {"row-gap", "clamp(10px, 5vw, 50px)"} in result
      assert {"column-gap", "clamp(10px, 5vw, 50px)"} in result
    end

    test "handles negative values in margin" do
      result = FlattenShorthands.expand_declaration("margin", "-10px -20px", %{})

      assert {"margin-top", "-10px"} in result
      assert {"margin-right", "-20px"} in result
      assert {"margin-bottom", "-10px"} in result
      assert {"margin-left", "-20px"} in result
    end

    test "handles 0 values" do
      result = FlattenShorthands.expand_declaration("padding", "0 10px 0 0", %{})

      assert {"padding-top", "0"} in result
      assert {"padding-right", "10px"} in result
      assert {"padding-bottom", "0"} in result
      assert {"padding-left", "0"} in result
    end

    test "handles inherit value" do
      result = FlattenShorthands.expand_declaration("margin", "inherit", %{})

      assert {"margin-top", "inherit"} in result
      assert {"margin-right", "inherit"} in result
      assert {"margin-bottom", "inherit"} in result
      assert {"margin-left", "inherit"} in result
    end

    test "handles initial value" do
      result = FlattenShorthands.expand_declaration("padding", "initial", %{})

      assert {"padding-top", "initial"} in result
      assert {"padding-right", "initial"} in result
      assert {"padding-bottom", "initial"} in result
      assert {"padding-left", "initial"} in result
    end

    test "handles unset value" do
      result = FlattenShorthands.expand_declaration("gap", "unset", %{})

      assert {"row-gap", "unset"} in result
      assert {"column-gap", "unset"} in result
    end
  end
end
