defmodule LiveStyle.ConstsTest do
  @moduledoc """
  Tests for LiveStyle's consts macro.

  These tests verify that LiveStyle's constants implementation matches StyleX's
  defineConsts API behavior.

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-defineConsts-test.js
  """
  use LiveStyle.TestCase

  # ===========================================================================
  # Using constants in class definitions
  # ===========================================================================

  describe "constants in class definitions" do
    defmodule ZIndexConstants do
      use LiveStyle

      consts(
        dropdown: 1000,
        modal: 2000,
        tooltip: 3000
      )

      class(:dropdown, z_index: const(:dropdown))
      class(:modal, z_index: const(:modal))
      class(:tooltip, z_index: const(:tooltip))
    end

    test "numeric constants are inlined in generated CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "z-index:1000"
      assert css =~ "z-index:2000"
      assert css =~ "z-index:3000"
    end

    defmodule BreakpointConstants do
      use LiveStyle

      consts(
        breakpoint_sm: "@media (min-width: 768px)",
        breakpoint_lg: "@media (min-width: 1024px)"
      )

      class(:responsive,
        color: %{
          :default => "red",
          const(:breakpoint_sm) => "blue",
          const(:breakpoint_lg) => "green"
        }
      )
    end

    test "string constants work as media query conditions" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "@media (min-width: 768px)"
      assert css =~ "@media (min-width: 1024px)"
      assert css =~ "color:red"
      assert css =~ "color:blue"
      assert css =~ "color:green"
    end

    defmodule StringConstants do
      use LiveStyle

      consts(
        font_mono: "monospace",
        shadow_sm: "0 1px 2px black"
      )

      class(:code, font_family: const(:font_mono))
      class(:card, box_shadow: const(:shadow_sm))
    end

    test "string constants are inlined in generated CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "font-family:monospace"
      assert css =~ "box-shadow:0 1px 2px black"
    end
  end

  # ===========================================================================
  # Cross-module constant references
  # ===========================================================================

  describe "cross-module constant references" do
    defmodule SharedConsts do
      use LiveStyle

      consts(
        primary_color: "rebeccapurple",
        base_spacing: "16px"
      )
    end

    defmodule ConstsConsumer do
      use LiveStyle
      alias LiveStyle.ConstsTest.SharedConsts

      class(:themed_box,
        color: const({SharedConsts, :primary_color}),
        padding: const({SharedConsts, :base_spacing})
      )
    end

    test "constants can be referenced from other modules in CSS output" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "color:rebeccapurple"
      assert css =~ "padding:16px"
    end
  end

  # ===========================================================================
  # Constants don't generate CSS on their own
  # ===========================================================================

  describe "constants don't generate standalone CSS" do
    defmodule UnusedConstants do
      use LiveStyle

      consts(
        unused_value: "should-not-appear",
        another_unused: "also-not-in-css"
      )
    end

    test "unused constants don't appear in CSS output" do
      css = LiveStyle.Compiler.generate_css()

      refute css =~ "should-not-appear"
      refute css =~ "also-not-in-css"
    end
  end

  # ===========================================================================
  # Edge cases
  # ===========================================================================

  describe "edge case values" do
    defmodule EdgeCaseConstants do
      use LiveStyle

      consts(
        zero_value: 0,
        negative_value: -1,
        float_value: 0.5,
        url_value: "url(image.png)"
      )

      class(:zero_index, z_index: const(:zero_value))
      class(:negative_index, z_index: const(:negative_value))
      class(:half_opacity, opacity: const(:float_value))
      class(:bg_image, background_image: const(:url_value))
    end

    test "zero and negative constants work in CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "z-index:0"
      assert css =~ "z-index:-1"
    end

    test "float constants work in CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "opacity:0.5"
    end

    test "constants with special characters work in CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "background-image:url(image.png)"
    end
  end
end
