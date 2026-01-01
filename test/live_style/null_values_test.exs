defmodule LiveStyle.NullValuesTest do
  @moduledoc """
  Tests for null value handling in LiveStyle.

  These tests verify StyleX-compatible behavior where `nil` values are used
  to "unset" or "reset" styles. Setting a style property to `nil` removes
  any previously applied style for that property - it doesn't generate CSS.

  ## StyleX Reference
  From transform-stylex-props-test.js "stylex call with reverting by null":
  - When styles.red (color: 'red') is applied first and styles.revert (color: null) second,
    the result is an empty object {} - the style is completely removed
  - When styles.revert (color: null) is applied first and styles.red second,
    the result has the red class - red wins since it comes after
  """
  use LiveStyle.TestCase

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.Class

  # ============================================================================
  # Test Modules - Static nil values
  # ============================================================================

  defmodule NullStaticStyles do
    use LiveStyle

    # A style with a regular color value
    class(:red, color: "red")

    # A style that "unsets" the color - should not generate CSS
    class(:revert, color: nil)

    # Multiple properties, one nil
    class(:partial_nil,
      color: "blue",
      background_color: nil
    )
  end

  # ============================================================================
  # Test Modules - Conditional nil values
  # ============================================================================

  defmodule NullConditionalStyles do
    use LiveStyle

    # Default value with nil for hover
    # This means: apply color:blue by default, but unset it on hover
    class(:default_with_nil_hover,
      color: [
        default: "blue",
        ":hover": nil
      ]
    )

    # Nil default with conditional value
    # This means: no default color, but apply red on hover
    class(:nil_default_with_hover,
      color: [
        default: nil,
        ":hover": "red"
      ]
    )
  end

  # ============================================================================
  # Tests - Static nil values
  # ============================================================================

  describe "static nil values" do
    test "nil value property is excluded from generated CSS" do
      # StyleX: color: null produces kMwMTN: null in the compiled object
      # No CSS is generated for null values
      rule =
        Class.lookup!({LiveStyle.NullValuesTest.NullStaticStyles, :revert})

      # The rule should exist but with no atomic classes (or nil class for color)
      # StyleX stores null as the className for the property key
      assert rule != nil

      # Either no atomic classes at all, or the color class is nil
      case rule.atomic_classes do
        nil ->
          assert true

        %{} = classes when map_size(classes) == 0 ->
          assert true

        %{"color" => color_meta} ->
          # StyleX behavior: className is null for null values
          assert color_meta.class == nil or color_meta == nil
      end
    end

    test "nil value results in empty class string" do
      # When only nil values exist, the class string should be empty
      class = Compiler.get_css_class(NullStaticStyles, :revert)
      assert class == "" or class == nil
    end

    test "partial nil - only non-nil properties generate classes" do
      # StyleX: multiple properties where one is null
      # Only the non-null property generates a class
      rule =
        Class.lookup!({LiveStyle.NullValuesTest.NullStaticStyles, :partial_nil})

      # color: blue should generate a class
      assert rule.atomic_classes["color"] != nil
      assert rule.atomic_classes["color"].class != nil

      # background-color: nil should not generate a class
      # Either the key is missing or the value is nil
      bg_meta = Map.get(rule.atomic_classes, "background-color")
      assert bg_meta == nil or bg_meta.class == nil
    end

    test "nil value does not produce CSS output" do
      # Generate the CSS and verify nil values don't appear
      css = Compiler.generate_css()

      # The CSS should NOT contain any rules for the :revert style
      # (since color: nil doesn't generate CSS)
      # We can verify by checking that there's no standalone rule
      # that only contains content from the :revert rule
      refute css =~ "color:nil"
      refute css =~ "color:null"
    end
  end

  # ============================================================================
  # Tests - Style merging with nil values
  # ============================================================================

  describe "style merging with nil values" do
    test "nil value after regular value removes the property" do
      # StyleX: stylex.props([styles.red, styles.revert]) -> {}
      # The nil value removes the previously applied style
      attrs = Compiler.get_css(NullStaticStyles, [:red, :revert])

      # Result should have no classes (empty string)
      assert attrs.class == "" or attrs.class == nil
    end

    test "regular value after nil value applies the value" do
      # StyleX: stylex.props([styles.revert, styles.red]) -> { className: "x1e2nbdu" }
      # The regular value wins since it comes after
      attrs = Compiler.get_css(NullStaticStyles, [:revert, :red])

      # Result should have the red class
      assert attrs.class != nil
      assert attrs.class != ""

      # Verify it's the red color class
      rule = Class.lookup!({LiveStyle.NullValuesTest.NullStaticStyles, :red})
      red_class = rule.atomic_classes["color"].class
      assert attrs.class =~ red_class
    end

    test "nil in middle of style list removes that property" do
      # Multiple styles where nil appears in the middle
      # [:red, :revert, :partial_nil]
      # red has color:red
      # revert has color:nil (removes red's color)
      # partial_nil has color:blue (re-applies color)
      attrs = Compiler.get_css(NullStaticStyles, [:red, :revert, :partial_nil])

      # Result should have partial_nil's blue color, not red's color
      blue_rule =
        Class.lookup!({LiveStyle.NullValuesTest.NullStaticStyles, :partial_nil})

      blue_class = blue_rule.atomic_classes["color"].class

      assert attrs.class =~ blue_class
    end
  end

  # ============================================================================
  # Tests - Conditional nil values
  # ============================================================================

  describe "conditional nil values" do
    test "nil in non-default condition has no effect" do
      # StyleX: Using null for a non-default condition has no effect
      # and should be considered invalid (but doesn't error)
      rule =
        Class.lookup!({LiveStyle.NullValuesTest.NullConditionalStyles, :default_with_nil_hover})

      # Should have a default class
      classes = rule.atomic_classes["color"].classes
      assert Map.has_key?(classes, :default)
      assert classes[:default].class != nil

      # :hover might exist but with nil class, or not exist at all
      hover = Map.get(classes, ":hover")
      assert hover == nil or hover.class == nil
    end

    test "nil default with conditional value" do
      # StyleX: default: null means no style in the default case
      # but the hover style should still apply
      rule =
        Class.lookup!({LiveStyle.NullValuesTest.NullConditionalStyles, :nil_default_with_hover})

      classes = rule.atomic_classes["color"].classes

      # Default should be nil or missing
      default = Map.get(classes, :default)
      assert default == nil or default.class == nil

      # :hover should have a class
      assert Map.has_key?(classes, ":hover")
      assert classes[":hover"].class != nil
    end
  end
end
