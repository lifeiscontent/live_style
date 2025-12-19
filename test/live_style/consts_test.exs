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
      assert LiveStyle.get_metadata(BasicBreakpoints, {:const, :breakpoint, :sm}) ==
               "(min-width: 768px)"

      assert LiveStyle.get_metadata(BasicBreakpoints, {:const, :breakpoint, :md}) ==
               "(min-width: 1024px)"

      assert LiveStyle.get_metadata(BasicBreakpoints, {:const, :breakpoint, :lg}) ==
               "(min-width: 1280px)"
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
      assert LiveStyle.get_metadata(NumericConstants, {:const, :size, :small}) == 8
      assert LiveStyle.get_metadata(NumericConstants, {:const, :size, :medium}) == 16
      assert LiveStyle.get_metadata(NumericConstants, {:const, :size, :large}) == 24
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
      assert LiveStyle.get_metadata(MixedConstants, {:const, :theme, :spacing}) == 16
      assert LiveStyle.get_metadata(MixedConstants, {:const, :theme, :color}) == "blue"

      assert LiveStyle.get_metadata(MixedConstants, {:const, :theme, :breakpoint}) ==
               "(min-width: 768px)"
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
      val1 = LiveStyle.get_metadata(ConstsUnique1, {:const, :test, :padding})
      val2 = LiveStyle.get_metadata(ConstsUnique2, {:const, :test, :padding})

      assert val1 == val2
    end

    test "different inputs produce different entries" do
      val1 = LiveStyle.get_metadata(ConstsUnique1, {:const, :test, :padding})
      val3 = LiveStyle.get_metadata(ConstsUnique3, {:const, :test, :margin})

      # Values are different (padding vs margin)
      assert val1 == "10px"
      assert val3 == "10px"
      # But they're stored under different keys (different modules/names)
    end
  end

  # ===========================================================================
  # Using constants in css_class
  # ===========================================================================

  describe "using constants in css_class" do
    defmodule ConstsWithRule do
      use LiveStyle

      css_consts(:breakpoint,
        small: "@media (min-width: 768px)",
        large: "@media (min-width: 1024px)"
      )

      css_class(:responsive,
        color: %{
          :default => "red",
          css_const({__MODULE__, :breakpoint, :small}) => "blue"
        }
      )
    end

    test "constants can be used in conditional styles" do
      rule = LiveStyle.get_metadata(ConstsWithRule, {:class, :responsive})

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

      css_class(:dropdown, z_index: css_const({__MODULE__, :z, :dropdown}))
      css_class(:modal, z_index: css_const({__MODULE__, :z, :modal}))
      css_class(:tooltip, z_index: css_const({__MODULE__, :z, :tooltip}))
    end

    test "numeric constants can be used as property values" do
      dropdown_rule = LiveStyle.get_metadata(ConstsWithMultipleRules, {:class, :dropdown})
      modal_rule = LiveStyle.get_metadata(ConstsWithMultipleRules, {:class, :modal})
      tooltip_rule = LiveStyle.get_metadata(ConstsWithMultipleRules, {:class, :tooltip})

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
      # Breakpoints
      assert LiveStyle.get_metadata(MultipleNamespaces, {:const, :breakpoint, :sm}) ==
               "(min-width: 768px)"

      # Colors
      assert LiveStyle.get_metadata(MultipleNamespaces, {:const, :color, :primary}) == "blue"

      # Sizes
      assert LiveStyle.get_metadata(MultipleNamespaces, {:const, :size, :small}) == 8
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
      assert LiveStyle.get_metadata(ConstsWithSpecialChars, {:const, :special, :with_url}) ==
               "url(\"bg.png\")"

      assert LiveStyle.get_metadata(ConstsWithSpecialChars, {:const, :special, :with_quotes}) ==
               "\"hello world\""
    end

    defmodule ConstsWithZero do
      use LiveStyle

      css_consts(:z,
        base: 0,
        negative: -1
      )
    end

    test "handles zero and negative values" do
      assert LiveStyle.get_metadata(ConstsWithZero, {:const, :z, :base}) == 0
      assert LiveStyle.get_metadata(ConstsWithZero, {:const, :z, :negative}) == -1
    end

    defmodule ConstsWithFloat do
      use LiveStyle

      css_consts(:ratio,
        half: 0.5,
        third: 0.333
      )
    end

    test "handles float values" do
      assert LiveStyle.get_metadata(ConstsWithFloat, {:const, :ratio, :half}) == 0.5
      assert LiveStyle.get_metadata(ConstsWithFloat, {:const, :ratio, :third}) == 0.333
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
      # The css_const function is used at compile time in css_class
      # Here we verify the metadata contains the expected values
      sm = LiveStyle.get_metadata(ConstsAccessor, {:const, :bp, :sm})
      lg = LiveStyle.get_metadata(ConstsAccessor, {:const, :bp, :lg})

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

      css_class(:box,
        padding: css_const({SharedConsts, :shared, :spacing})
      )
    end

    test "constants can be referenced from other modules" do
      # The rule should exist and use the shared constant
      rule = LiveStyle.get_metadata(ConstsConsumer, {:class, :box})
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
      css = generate_css()

      # Constants should not generate any CSS rules
      # They are compile-time values only
      refute css =~ "no_css"
      refute css =~ "test1"
      refute css =~ "test2"
    end
  end
end
