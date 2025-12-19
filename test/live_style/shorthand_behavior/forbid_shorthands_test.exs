defmodule LiveStyle.ShorthandBehavior.ForbidShorthandsTest do
  @moduledoc """
  Tests for the ForbidShorthands behavior.

  This tests the ForbidShorthands behavior which:
  1. Raises compile-time errors for disallowed shorthand properties
  2. Passes through allowed properties unchanged
  3. Provides helpful error messages suggesting longhand alternatives

  The ForbidShorthands behavior is useful when you want to enforce explicit
  longhand usage for ambiguous shorthands like `border`, `background`, etc.
  """

  use ExUnit.Case, async: true

  alias LiveStyle.ShorthandBehavior.ForbidShorthands

  # ==========================================================================
  # Allowed Properties (pass through unchanged)
  # ==========================================================================

  describe "allowed properties" do
    test "margin passes through" do
      result = ForbidShorthands.expand("margin", "10px")
      assert result == [{:margin, "10px"}]
    end

    test "margin with multiple values passes through" do
      result = ForbidShorthands.expand("margin", "10px 20px 30px 40px")
      assert result == [{:margin, "10px 20px 30px 40px"}]
    end

    test "padding passes through" do
      result = ForbidShorthands.expand("padding", "10px")
      assert result == [{:padding, "10px"}]
    end

    test "gap passes through" do
      result = ForbidShorthands.expand("gap", "10px 20px")
      assert result == [{:gap, "10px 20px"}]
    end

    test "border-radius passes through" do
      result = ForbidShorthands.expand("border-radius", "4px")
      assert result == [{:border_radius, "4px"}]
    end

    test "overflow passes through" do
      result = ForbidShorthands.expand("overflow", "hidden")
      assert result == [{:overflow, "hidden"}]
    end

    test "flex passes through" do
      result = ForbidShorthands.expand("flex", "1 1 auto")
      assert result == [{:flex, "1 1 auto"}]
    end

    test "inset passes through" do
      result = ForbidShorthands.expand("inset", "10px")
      assert result == [{:inset, "10px"}]
    end
  end

  # ==========================================================================
  # Longhand Properties (always allowed)
  # ==========================================================================

  describe "longhand properties" do
    test "color passes through" do
      result = ForbidShorthands.expand("color", "red")
      assert result == [{:color, "red"}]
    end

    test "display passes through" do
      result = ForbidShorthands.expand("display", "flex")
      assert result == [{:display, "flex"}]
    end

    test "width passes through" do
      result = ForbidShorthands.expand("width", "100px")
      assert result == [{:width, "100px"}]
    end

    test "height passes through" do
      result = ForbidShorthands.expand("height", "100px")
      assert result == [{:height, "100px"}]
    end

    test "margin-top passes through" do
      result = ForbidShorthands.expand("margin-top", "10px")
      assert result == [{:margin_top, "10px"}]
    end

    test "padding-left passes through" do
      result = ForbidShorthands.expand("padding-left", "10px")
      assert result == [{:padding_left, "10px"}]
    end

    test "border-width passes through" do
      result = ForbidShorthands.expand("border-width", "1px")
      assert result == [{:border_width, "1px"}]
    end

    test "border-style passes through" do
      result = ForbidShorthands.expand("border-style", "solid")
      assert result == [{:border_style, "solid"}]
    end

    test "border-color passes through" do
      result = ForbidShorthands.expand("border-color", "red")
      assert result == [{:border_color, "red"}]
    end

    test "background-color passes through" do
      result = ForbidShorthands.expand("background-color", "red")
      assert result == [{:background_color, "red"}]
    end
  end

  # ==========================================================================
  # Disallowed Shorthands - border family
  # ==========================================================================

  describe "disallowed shorthand: border" do
    test "raises error for border shorthand" do
      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        ForbidShorthands.expand("border", "1px solid black")
      end
    end

    test "error message suggests border-width, border-style, border-color" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("border", "1px solid black")
        end

      assert error.message =~ "border-width"
      assert error.message =~ "border-style"
      assert error.message =~ "border-color"
    end
  end

  describe "disallowed shorthand: border-top" do
    test "raises error for border-top" do
      assert_raise ArgumentError, ~r/'border-top' is not supported/, fn ->
        ForbidShorthands.expand("border-top", "1px solid black")
      end
    end

    test "error message suggests longhand alternatives" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("border-top", "1px solid black")
        end

      assert error.message =~ "border-top-width"
      assert error.message =~ "border-top-style"
      assert error.message =~ "border-top-color"
    end
  end

  describe "disallowed shorthand: border-right" do
    test "raises error for border-right" do
      assert_raise ArgumentError, ~r/'border-right' is not supported/, fn ->
        ForbidShorthands.expand("border-right", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-bottom" do
    test "raises error for border-bottom" do
      assert_raise ArgumentError, ~r/'border-bottom' is not supported/, fn ->
        ForbidShorthands.expand("border-bottom", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-left" do
    test "raises error for border-left" do
      assert_raise ArgumentError, ~r/'border-left' is not supported/, fn ->
        ForbidShorthands.expand("border-left", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-inline" do
    test "raises error for border-inline" do
      assert_raise ArgumentError, ~r/'border-inline' is not supported/, fn ->
        ForbidShorthands.expand("border-inline", "1px solid black")
      end
    end

    test "error message suggests logical longhand alternatives" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("border-inline", "1px solid black")
        end

      assert error.message =~ "border-inline-width"
      assert error.message =~ "border-inline-style"
      assert error.message =~ "border-inline-color"
    end
  end

  describe "disallowed shorthand: border-block" do
    test "raises error for border-block" do
      assert_raise ArgumentError, ~r/'border-block' is not supported/, fn ->
        ForbidShorthands.expand("border-block", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-inline-start" do
    test "raises error for border-inline-start" do
      assert_raise ArgumentError, ~r/'border-inline-start' is not supported/, fn ->
        ForbidShorthands.expand("border-inline-start", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-inline-end" do
    test "raises error for border-inline-end" do
      assert_raise ArgumentError, ~r/'border-inline-end' is not supported/, fn ->
        ForbidShorthands.expand("border-inline-end", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-block-start" do
    test "raises error for border-block-start" do
      assert_raise ArgumentError, ~r/'border-block-start' is not supported/, fn ->
        ForbidShorthands.expand("border-block-start", "1px solid black")
      end
    end
  end

  describe "disallowed shorthand: border-block-end" do
    test "raises error for border-block-end" do
      assert_raise ArgumentError, ~r/'border-block-end' is not supported/, fn ->
        ForbidShorthands.expand("border-block-end", "1px solid black")
      end
    end
  end

  # ==========================================================================
  # Disallowed Shorthands - background
  # ==========================================================================

  describe "disallowed shorthand: background" do
    test "raises error for background" do
      assert_raise ArgumentError, ~r/'background' is not supported/, fn ->
        ForbidShorthands.expand("background", "red url(bg.png) center")
      end
    end

    test "error message suggests longhand alternatives" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("background", "red")
        end

      assert error.message =~ "background-color"
      assert error.message =~ "background-image"
    end
  end

  # ==========================================================================
  # Disallowed Shorthands - animation and transition
  # ==========================================================================

  describe "disallowed shorthand: animation" do
    test "raises error for animation" do
      assert_raise ArgumentError, ~r/'animation' is not supported/, fn ->
        ForbidShorthands.expand("animation", "spin 1s linear infinite")
      end
    end

    test "error message suggests animation longhands" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("animation", "spin 1s")
        end

      assert error.message =~ "animation-name"
      assert error.message =~ "animation-duration"
    end
  end

  describe "disallowed shorthand: transition" do
    test "raises error for transition" do
      assert_raise ArgumentError, ~r/'transition' is not supported/, fn ->
        ForbidShorthands.expand("transition", "all 0.3s ease")
      end
    end

    test "error message suggests transition longhands" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("transition", "all 0.3s")
        end

      assert error.message =~ "transition-property"
      assert error.message =~ "transition-duration"
    end
  end

  # ==========================================================================
  # Disallowed Shorthands - other
  # ==========================================================================

  describe "disallowed shorthand: font" do
    test "raises error for font" do
      assert_raise ArgumentError, ~r/'font' is not supported/, fn ->
        ForbidShorthands.expand("font", "16px/1.5 Arial")
      end
    end

    test "error message suggests font longhands" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("font", "16px Arial")
        end

      assert error.message =~ "font-size"
      assert error.message =~ "font-family"
    end
  end

  describe "disallowed shorthand: outline" do
    test "raises error for outline" do
      assert_raise ArgumentError, ~r/'outline' is not supported/, fn ->
        ForbidShorthands.expand("outline", "1px solid blue")
      end
    end
  end

  describe "disallowed shorthand: text-decoration" do
    test "raises error for text-decoration" do
      assert_raise ArgumentError, ~r/'text-decoration' is not supported/, fn ->
        ForbidShorthands.expand("text-decoration", "underline red wavy")
      end
    end
  end

  describe "disallowed shorthand: columns" do
    test "raises error for columns" do
      assert_raise ArgumentError, ~r/'columns' is not supported/, fn ->
        ForbidShorthands.expand("columns", "3 200px")
      end
    end
  end

  describe "disallowed shorthand: flex-flow" do
    test "raises error for flex-flow" do
      assert_raise ArgumentError, ~r/'flex-flow' is not supported/, fn ->
        ForbidShorthands.expand("flex-flow", "row wrap")
      end
    end

    test "error message suggests flex-direction and flex-wrap" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand("flex-flow", "row wrap")
        end

      assert error.message =~ "flex-direction"
      assert error.message =~ "flex-wrap"
    end
  end

  describe "disallowed shorthand: grid" do
    test "raises error for grid" do
      assert_raise ArgumentError, ~r/'grid' is not supported/, fn ->
        ForbidShorthands.expand("grid", "auto / 1fr 1fr")
      end
    end
  end

  describe "disallowed shorthand: grid-area" do
    test "raises error for grid-area" do
      assert_raise ArgumentError, ~r/'grid-area' is not supported/, fn ->
        ForbidShorthands.expand("grid-area", "header")
      end
    end
  end

  describe "disallowed shorthand: list-style" do
    test "raises error for list-style" do
      assert_raise ArgumentError, ~r/'list-style' is not supported/, fn ->
        ForbidShorthands.expand("list-style", "disc inside")
      end
    end
  end
end
