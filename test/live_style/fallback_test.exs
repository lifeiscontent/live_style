defmodule LiveStyle.FallbackTest do
  @moduledoc """
  Tests for fallback/1 (StyleX firstThatWorks equivalent) and plain array fallbacks.

  These tests verify that LiveStyle matches StyleX's behavior for:
  1. Plain arrays - use variableFallbacks (nest vars only when non-var comes before var)
  2. fallback() - use firstThatWorks (reverse non-vars, nest vars when var comes first)

  Reference: https://stylexjs.com/blog/v0.8.0/#theming-improvements
  """
  use LiveStyle.TestCase

  alias LiveStyle.Compiler.Class

  # ===========================================================================
  # Plain Array Fallbacks (StyleX variableFallbacks behavior)
  # Arrays preserve order, CSS vars get nested only when non-var comes BEFORE var
  # ===========================================================================

  defmodule PlainArrayFallbacks do
    use LiveStyle

    # No CSS variables - order preserved
    class(:no_vars, position: ["sticky", "fixed"])

    # CSS var first, non-var after - NOT nested (two declarations)
    class(:var_first, color: ["var(--color)", "red"])

    # Non-var first, CSS var after - nested into var(--color, red)
    class(:var_last, color: ["red", "var(--color)"])

    # Multiple CSS vars - nested together
    class(:multi_vars, color: ["var(--primary)", "var(--fallback)"])

    # Multiple CSS vars with final non-var fallback
    class(:multi_vars_with_fallback,
      color: ["blue", "var(--primary)", "var(--fallback)"]
    )
  end

  # ===========================================================================
  # Explicit fallback() (StyleX firstThatWorks behavior)
  # Reverses non-var values, nests vars when var comes FIRST
  # ===========================================================================

  defmodule ExplicitFirstThatWorks do
    use LiveStyle

    # No CSS variables - reversed order
    class(:no_vars, position: fallback(["sticky", "fixed"]))

    # CSS var first, non-var after - nested into var(--color, red)
    class(:var_first, color: fallback(["var(--color)", "red"]))

    # Non-var first, CSS var after - NOT nested (two declarations, reversed)
    class(:var_last, color: fallback(["red", "var(--color)"]))

    # Multiple CSS vars with fallback - all nested
    class(:multi_vars_with_fallback,
      color: fallback(["var(--primary)", "var(--secondary)", "blue"])
    )
  end

  # ===========================================================================
  # Tests for Plain Array Fallbacks
  # ===========================================================================

  describe "plain array fallbacks (variableFallbacks behavior)" do
    test "no CSS variables - order preserved" do
      # StyleX: position: ['sticky', 'fixed'] -> position:sticky;position:fixed
      rule = Class.lookup!({PlainArrayFallbacks, :no_vars})

      position = rule.atomic_classes["position"]
      assert position.class == "x1ruww2u"
      assert position.ltr == ".x1ruww2u{position:sticky;position:fixed}"
      assert position.priority == 3000
    end

    test "CSS var first, non-var after - two declarations (not nested)" do
      # StyleX variableFallbacks: ['var(--color)', 'red'] -> color:var(--color);color:red
      rule = Class.lookup!({PlainArrayFallbacks, :var_first})

      color = rule.atomic_classes["color"]
      assert color.ltr == ".x1nv2f59{color:var(--color);color:red}"
    end

    test "non-var first, CSS var after - nested into var()" do
      # StyleX variableFallbacks: ['red', 'var(--color)'] -> color:var(--color,red)
      rule = Class.lookup!({PlainArrayFallbacks, :var_last})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color,red)"
    end

    test "multiple CSS vars - nested together" do
      # When all values are vars with no non-var before, they get nested
      # ['var(--primary)', 'var(--fallback)'] -> var(--primary,var(--fallback))
      rule = Class.lookup!({PlainArrayFallbacks, :multi_vars})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "var(--primary,var(--fallback))"
    end

    test "non-var before multiple CSS vars - nested with fallback" do
      # StyleX: ['blue', 'var(--primary)', 'var(--fallback)']
      # -> color:var(--primary,var(--fallback,blue))
      rule = Class.lookup!({PlainArrayFallbacks, :multi_vars_with_fallback})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "var(--primary,var(--fallback,blue))"
    end
  end

  # ===========================================================================
  # Tests for Explicit fallback()
  # ===========================================================================

  describe "explicit fallback() (firstThatWorks behavior)" do
    test "no CSS variables - reversed order" do
      # StyleX firstThatWorks('sticky', 'fixed') -> position:fixed;position:sticky
      rule = Class.lookup!({ExplicitFirstThatWorks, :no_vars})

      position = rule.atomic_classes["position"]
      # Note: different class name due to different hash (reversed order)
      assert position.ltr =~ "position:fixed;position:sticky"
    end

    test "CSS var first, non-var after - nested into var()" do
      # StyleX firstThatWorks('var(--color)', 'red') -> color:var(--color,red)
      rule = Class.lookup!({ExplicitFirstThatWorks, :var_first})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color,red)"
    end

    test "non-var first, CSS var after - two declarations (reversed)" do
      # StyleX firstThatWorks('red', 'var(--color)') -> color:var(--color);color:red
      rule = Class.lookup!({ExplicitFirstThatWorks, :var_last})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color);color:red"
    end

    test "multiple CSS vars with fallback - all nested" do
      # StyleX firstThatWorks('var(--primary)', 'var(--secondary)', 'blue')
      # -> color:var(--primary,var(--secondary,blue))
      rule = Class.lookup!({ExplicitFirstThatWorks, :multi_vars_with_fallback})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "var(--primary,var(--secondary,blue))"
    end
  end

  # ===========================================================================
  # StyleX Parity Tests - Exact Output Matching
  # ===========================================================================

  defmodule StyleXParityFirstThatWorks do
    use LiveStyle

    # From StyleX tests: transform-stylex-create-test.js
    # test('args: value, var')
    # color: stylex.firstThatWorks('red', 'var(--color)')
    # Expected: ".x1nv2f59{color:var(--color);color:red}"
    class(:value_then_var, color: fallback(["red", "var(--color)"]))

    # test('args: var, value')
    # color: stylex.firstThatWorks('var(--color)', 'red')
    # Expected: ".x8nmrrw{color:var(--color,red)}"
    class(:var_then_value, color: fallback(["var(--color)", "red"]))

    # test('args: var, var')
    # color: stylex.firstThatWorks('var(--color)', 'var(--otherColor)')
    # Expected: ".x1775bb3{color:var(--color,var(--otherColor))}"
    class(:var_then_var, color: fallback(["var(--color)", "var(--otherColor)"]))

    # test('args: var, var, var')
    # color: stylex.firstThatWorks('var(--color)', 'var(--secondColor)', 'var(--thirdColor)')
    # Expected: ".xsrkhny{color:var(--color,var(--secondColor,var(--thirdColor)))}"
    class(:three_vars,
      color: fallback(["var(--color)", "var(--secondColor)", "var(--thirdColor)"])
    )
  end

  describe "StyleX parity - firstThatWorks CSS format" do
    test "firstThatWorks('red', 'var(--color)') produces correct format" do
      # StyleX format: color:var(--color);color:red (two declarations, var first)
      rule = Class.lookup!({StyleXParityFirstThatWorks, :value_then_var})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color);color:red"
    end

    test "firstThatWorks('var(--color)', 'red') produces nested var()" do
      # StyleX format: color:var(--color,red) (nested)
      rule = Class.lookup!({StyleXParityFirstThatWorks, :var_then_value})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color,red)"
    end

    test "firstThatWorks('var(--color)', 'var(--otherColor)') produces nested vars" do
      # StyleX format: color:var(--color,var(--otherColor)) (nested)
      rule = Class.lookup!({StyleXParityFirstThatWorks, :var_then_var})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color,var(--otherColor))"
    end

    test "firstThatWorks with three vars produces deeply nested vars" do
      # StyleX format: color:var(--color,var(--secondColor,var(--thirdColor)))
      rule = Class.lookup!({StyleXParityFirstThatWorks, :three_vars})

      color = rule.atomic_classes["color"]
      assert color.ltr =~ "color:var(--color,var(--secondColor,var(--thirdColor)))"
    end
  end
end
