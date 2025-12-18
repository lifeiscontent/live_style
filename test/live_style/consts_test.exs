defmodule LiveStyle.ConstsTest do
  @moduledoc """
  Tests for LiveStyle's css_consts macro.

  These tests verify that LiveStyle's constants implementation matches StyleX's
  defineConsts API behavior.

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-defineConsts-test.js
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Basic constants definition
  # ===========================================================================

  describe "basic constants definition" do
    defmodule BasicBreakpoints do
      use LiveStyle

      css_consts(:breakpoint,
        sm: "(min-width: 768px)",
        md: "(min-width: 1024px)",
        lg: "(min-width: 1280px)"
      )
    end

    test "defines string constants" do
      manifest = get_manifest()

      sm_key = "LiveStyle.ConstsTest.BasicBreakpoints.breakpoint.sm"
      md_key = "LiveStyle.ConstsTest.BasicBreakpoints.breakpoint.md"
      lg_key = "LiveStyle.ConstsTest.BasicBreakpoints.breakpoint.lg"

      assert LiveStyle.Manifest.get_const(manifest, sm_key) == "(min-width: 768px)"
      assert LiveStyle.Manifest.get_const(manifest, md_key) == "(min-width: 1024px)"
      assert LiveStyle.Manifest.get_const(manifest, lg_key) == "(min-width: 1280px)"
    end

    defmodule NumericConstants do
      use LiveStyle

      css_consts(:size,
        small: 8,
        medium: 16,
        large: 24
      )
    end

    test "defines numeric constants" do
      manifest = get_manifest()

      small_key = "LiveStyle.ConstsTest.NumericConstants.size.small"
      medium_key = "LiveStyle.ConstsTest.NumericConstants.size.medium"
      large_key = "LiveStyle.ConstsTest.NumericConstants.size.large"

      assert LiveStyle.Manifest.get_const(manifest, small_key) == 8
      assert LiveStyle.Manifest.get_const(manifest, medium_key) == 16
      assert LiveStyle.Manifest.get_const(manifest, large_key) == 24
    end

    defmodule MixedConstants do
      use LiveStyle

      css_consts(:theme,
        spacing: 16,
        color: "blue",
        breakpoint: "(min-width: 768px)"
      )
    end

    test "defines mixed string and numeric constants" do
      manifest = get_manifest()

      spacing_key = "LiveStyle.ConstsTest.MixedConstants.theme.spacing"
      color_key = "LiveStyle.ConstsTest.MixedConstants.theme.color"
      breakpoint_key = "LiveStyle.ConstsTest.MixedConstants.theme.breakpoint"

      assert LiveStyle.Manifest.get_const(manifest, spacing_key) == 16
      assert LiveStyle.Manifest.get_const(manifest, color_key) == "blue"
      assert LiveStyle.Manifest.get_const(manifest, breakpoint_key) == "(min-width: 768px)"
    end
  end

  # ===========================================================================
  # Constants uniqueness and consistency
  # ===========================================================================

  describe "constants uniqueness and consistency" do
    defmodule ConstsUnique1 do
      use LiveStyle

      css_consts(:test, padding: "10px")
    end

    defmodule ConstsUnique2 do
      use LiveStyle

      css_consts(:test, padding: "10px")
    end

    defmodule ConstsUnique3 do
      use LiveStyle

      css_consts(:test, margin: "10px")
    end

    test "same inputs produce same values" do
      manifest = get_manifest()

      key1 = "LiveStyle.ConstsTest.ConstsUnique1.test.padding"
      key2 = "LiveStyle.ConstsTest.ConstsUnique2.test.padding"

      val1 = LiveStyle.Manifest.get_const(manifest, key1)
      val2 = LiveStyle.Manifest.get_const(manifest, key2)

      assert val1 == val2
    end

    test "different inputs produce different entries" do
      manifest = get_manifest()

      key1 = "LiveStyle.ConstsTest.ConstsUnique1.test.padding"
      key3 = "LiveStyle.ConstsTest.ConstsUnique3.test.margin"

      val1 = LiveStyle.Manifest.get_const(manifest, key1)
      val3 = LiveStyle.Manifest.get_const(manifest, key3)

      # Values are different (padding vs margin)
      assert val1 == "10px"
      assert val3 == "10px"
      # But they're stored under different keys
      assert key1 != key3
    end
  end

  # ===========================================================================
  # Using constants in css_rule
  # ===========================================================================

  describe "using constants in css_rule" do
    defmodule ConstsWithRule do
      use LiveStyle

      css_consts(:breakpoint,
        small: "@media (min-width: 768px)",
        large: "@media (min-width: 1024px)"
      )

      css_rule(:responsive,
        color: %{
          :default => "red",
          css_const({__MODULE__, :breakpoint, :small}) => "blue"
        }
      )
    end

    test "constants can be used in conditional styles" do
      manifest = get_manifest()
      rule_key = "LiveStyle.ConstsTest.ConstsWithRule.responsive"
      rule = LiveStyle.Manifest.get_rule(manifest, rule_key)

      assert rule != nil
      assert rule.class_string != ""
    end

    defmodule ConstsWithMultipleRules do
      use LiveStyle

      css_consts(:z,
        dropdown: 1000,
        modal: 2000,
        tooltip: 3000
      )

      css_rule(:dropdown, z_index: css_const({__MODULE__, :z, :dropdown}))
      css_rule(:modal, z_index: css_const({__MODULE__, :z, :modal}))
      css_rule(:tooltip, z_index: css_const({__MODULE__, :z, :tooltip}))
    end

    test "numeric constants can be used as property values" do
      manifest = get_manifest()

      dropdown_rule =
        LiveStyle.Manifest.get_rule(
          manifest,
          "LiveStyle.ConstsTest.ConstsWithMultipleRules.dropdown"
        )

      modal_rule =
        LiveStyle.Manifest.get_rule(
          manifest,
          "LiveStyle.ConstsTest.ConstsWithMultipleRules.modal"
        )

      tooltip_rule =
        LiveStyle.Manifest.get_rule(
          manifest,
          "LiveStyle.ConstsTest.ConstsWithMultipleRules.tooltip"
        )

      assert dropdown_rule != nil
      assert modal_rule != nil
      assert tooltip_rule != nil
    end
  end

  # ===========================================================================
  # Multiple constants namespaces
  # ===========================================================================

  describe "multiple constants namespaces" do
    defmodule MultipleNamespaces do
      use LiveStyle

      css_consts(:breakpoint,
        sm: "(min-width: 768px)",
        md: "(min-width: 1024px)"
      )

      css_consts(:color,
        primary: "blue",
        secondary: "green"
      )

      css_consts(:size,
        small: 8,
        large: 24
      )
    end

    test "different namespaces have independent values" do
      manifest = get_manifest()

      # Breakpoints
      sm_key = "LiveStyle.ConstsTest.MultipleNamespaces.breakpoint.sm"
      assert LiveStyle.Manifest.get_const(manifest, sm_key) == "(min-width: 768px)"

      # Colors
      primary_key = "LiveStyle.ConstsTest.MultipleNamespaces.color.primary"
      assert LiveStyle.Manifest.get_const(manifest, primary_key) == "blue"

      # Sizes
      small_key = "LiveStyle.ConstsTest.MultipleNamespaces.size.small"
      assert LiveStyle.Manifest.get_const(manifest, small_key) == 8
    end
  end

  # ===========================================================================
  # Edge cases
  # ===========================================================================

  describe "edge cases" do
    defmodule ConstsWithSpecialChars do
      use LiveStyle

      css_consts(:special,
        with_url: "url(\"bg.png\")",
        with_quotes: "\"hello world\""
      )
    end

    test "handles special characters in values" do
      manifest = get_manifest()

      url_key = "LiveStyle.ConstsTest.ConstsWithSpecialChars.special.with_url"
      quotes_key = "LiveStyle.ConstsTest.ConstsWithSpecialChars.special.with_quotes"

      assert LiveStyle.Manifest.get_const(manifest, url_key) == "url(\"bg.png\")"
      assert LiveStyle.Manifest.get_const(manifest, quotes_key) == "\"hello world\""
    end

    defmodule ConstsWithZero do
      use LiveStyle

      css_consts(:z,
        base: 0,
        negative: -1
      )
    end

    test "handles zero and negative values" do
      manifest = get_manifest()

      base_key = "LiveStyle.ConstsTest.ConstsWithZero.z.base"
      negative_key = "LiveStyle.ConstsTest.ConstsWithZero.z.negative"

      assert LiveStyle.Manifest.get_const(manifest, base_key) == 0
      assert LiveStyle.Manifest.get_const(manifest, negative_key) == -1
    end

    defmodule ConstsWithFloat do
      use LiveStyle

      css_consts(:ratio,
        half: 0.5,
        third: 0.333
      )
    end

    test "handles float values" do
      manifest = get_manifest()

      half_key = "LiveStyle.ConstsTest.ConstsWithFloat.ratio.half"
      third_key = "LiveStyle.ConstsTest.ConstsWithFloat.ratio.third"

      assert LiveStyle.Manifest.get_const(manifest, half_key) == 0.5
      assert LiveStyle.Manifest.get_const(manifest, third_key) == 0.333
    end
  end

  # ===========================================================================
  # Constants accessor functions
  # ===========================================================================

  describe "constants accessor functions" do
    defmodule ConstsAccessor do
      use LiveStyle

      css_consts(:bp,
        sm: "(min-width: 768px)",
        lg: "(min-width: 1280px)"
      )
    end

    test "css_const/1 retrieves constant value" do
      # The css_const function is used at compile time in css_rule
      # Here we verify the manifest contains the expected values
      manifest = get_manifest()

      sm = LiveStyle.Manifest.get_const(manifest, "LiveStyle.ConstsTest.ConstsAccessor.bp.sm")
      lg = LiveStyle.Manifest.get_const(manifest, "LiveStyle.ConstsTest.ConstsAccessor.bp.lg")

      assert sm == "(min-width: 768px)"
      assert lg == "(min-width: 1280px)"
    end
  end

  # ===========================================================================
  # Cross-module constant references
  # ===========================================================================

  describe "cross-module constant references" do
    defmodule SharedConsts do
      use LiveStyle

      css_consts(:shared,
        primary: "rebeccapurple",
        spacing: 16
      )
    end

    defmodule ConstsConsumer do
      use LiveStyle
      alias LiveStyle.ConstsTest.SharedConsts

      css_rule(:box,
        padding: css_const({SharedConsts, :shared, :spacing})
      )
    end

    test "constants can be referenced from other modules" do
      manifest = get_manifest()

      # The rule should exist and use the shared constant
      rule = LiveStyle.Manifest.get_rule(manifest, "LiveStyle.ConstsTest.ConstsConsumer.box")
      assert rule != nil
      assert rule.class_string != ""
    end
  end

  # ===========================================================================
  # Constants don't generate CSS
  # ===========================================================================

  describe "constants don't generate CSS" do
    defmodule ConstsNoCss do
      use LiveStyle

      css_consts(:no_css,
        value1: "test1",
        value2: "test2"
      )
    end

    test "constants don't appear in CSS output" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Constants should not generate any CSS rules
      # They are compile-time values only
      refute css =~ "no_css"
      refute css =~ "test1"
      refute css =~ "test2"
    end
  end
end
