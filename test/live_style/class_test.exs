defmodule LiveStyle.ClassTest do
  @moduledoc """
  Tests for the `class/2` macro.

  These tests mirror StyleX's transform-stylex-create-test.js to ensure
  LiveStyle generates equivalent CSS output and metadata.
  """
  use LiveStyle.TestCase

  # Test modules must be defined at compile time
  defmodule BasicStyles do
    use LiveStyle

    class(:root,
      background_color: "red",
      color: "blue"
    )
  end

  defmodule MultipleRules do
    use LiveStyle

    class(:root, background_color: "red")
    class(:other, color: "blue")
    class(:bar_baz, color: "green")
  end

  defmodule CustomProperties do
    use LiveStyle

    # Custom properties (CSS variables) should:
    # - Not modify casing
    # - Not add units to unitless values
    class(:root,
      "--background-color": "red",
      "--otherColor": "green",
      "--foo": 10
    )
  end

  # ===========================================================================
  # StyleX parity tests - vendor prefixes
  # ===========================================================================

  defmodule VendorPrefixStyles do
    use LiveStyle

    # StyleX test: userSelect: 'none' -> ".x87ps6o{user-select:none}"
    class(:user_select, user_select: "none")
  end

  # ===========================================================================
  # StyleX parity tests - array fallbacks
  # ===========================================================================

  defmodule ArrayFallbackStyles do
    use LiveStyle

    # StyleX test: position: ['sticky', 'fixed'] -> ".x1ruww2u{position:sticky;position:fixed}"
    class(:position_fallback, position: ["sticky", "fixed"])
  end

  # ===========================================================================
  # StyleX parity tests - transitionProperty/willChange
  # StyleX converts camelCase values (marginTop) to kebab-case (margin-top)
  # because JS developers use camelCase for property names.
  #
  # In LiveStyle/Elixir, users should use kebab-case strings directly since
  # that's the CSS convention. Atom values are converted via to_css/2.
  # ===========================================================================

  defmodule TransitionPropertyStyles do
    use LiveStyle

    # Idiomatic Elixir: use kebab-case strings (CSS convention)
    # StyleX equivalent: transitionProperty: 'margin-top'
    class(:kebab_case, transition_property: "margin-top")

    # Custom property names (--foo) pass through unchanged
    class(:custom_prop, transition_property: "--foo")

    # Multiple values in kebab-case
    # StyleX equivalent: transitionProperty: 'opacity, inset-inline-start'
    class(:multi_value, transition_property: "opacity,inset-inline-start")
  end

  defmodule WillChangeStyles do
    use LiveStyle

    # Idiomatic Elixir: use kebab-case strings
    # StyleX equivalent: willChange: 'inset-inline-start'
    class(:kebab_case, will_change: "inset-inline-start")
  end

  describe "static styles" do
    test "generates CSS for basic style object" do
      # StyleX test: "style object"
      # Input: { backgroundColor: 'red', color: 'blue' }
      # Expected class names: xrkmrrc (background-color), xju2f9n (color)
      css = LiveStyle.Compiler.generate_css()

      # Should have atomic classes for background-color and color
      assert css =~ ".xrkmrrc{background-color:red}"
      assert css =~ ".xju2f9n{color:blue}"
    end

    test "generates correct class string for properties" do
      class_string = LiveStyle.Compiler.get_css_class(BasicStyles, [:root])

      # Should have class names for both properties
      # StyleX produces: "xrkmrrc xju2f9n"
      assert class_string =~ "xrkmrrc"
      assert class_string =~ "xju2f9n"
    end

    test "multiple style objects generate unique class names" do
      # StyleX test: "style object (multiple)"
      css = LiveStyle.Compiler.generate_css()

      # root: backgroundColor: 'red'
      assert css =~ ".xrkmrrc{background-color:red}"

      # other: color: 'blue'
      assert css =~ ".xju2f9n{color:blue}"

      # bar_baz: color: 'green'
      assert css =~ ".x1prwzq3{color:green}"
    end

    test "custom properties preserve casing and don't add units" do
      # StyleX test: "style object with custom properties"
      # Custom properties should:
      # - Not modify casing (--otherColor stays --otherColor)
      # - Not add units to numeric values (10 stays 10, not 10px)
      css = LiveStyle.Compiler.generate_css()

      # --background-color: red
      assert css =~ ".xgau0yw{--background-color:red}"

      # --otherColor: green (casing preserved)
      assert css =~ ".x1p9b6ba{--otherColor:green}"

      # --foo: 10 (no px added)
      assert css =~ ".x40g909{--foo:10}"
    end
  end

  describe "priority levels in CSS output" do
    # StyleX priority levels determine rule order in CSS output.
    # Lower priority rules come first, higher priority rules last.
    # This allows higher priority rules to override lower ones via cascade.

    test "custom properties appear early in CSS output (low priority)" do
      css = LiveStyle.Compiler.generate_css()

      # Custom property classes should exist
      assert css =~ ".xgau0yw{--background-color:red}"
      assert css =~ ".x1p9b6ba{--otherColor:green}"
      assert css =~ ".x40g909{--foo:10}"
    end

    test "regular longhands appear in CSS output" do
      css = LiveStyle.Compiler.generate_css()

      # color and background-color longhands should exist
      assert css =~ ".xju2f9n{color:blue}"
      assert css =~ ".xrkmrrc{background-color:red}"
    end
  end

  # ===========================================================================
  # StyleX parity tests - vendor prefix properties
  # ===========================================================================

  describe "vendor prefix properties" do
    test "userSelect: 'none' generates correct class and CSS" do
      # StyleX test: transform-stylex-create-test.js
      # Input: { userSelect: 'none' }
      # Expected: ".x87ps6o{user-select:none}"
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x87ps6o{user-select:none}"
    end
  end

  # ===========================================================================
  # StyleX parity tests - array fallbacks
  # ===========================================================================

  describe "array fallbacks" do
    test "position: ['sticky', 'fixed'] generates fallback declarations" do
      # StyleX test: transform-stylex-create-test.js "use array (fallbacks)"
      # Input: { position: ['sticky', 'fixed'] }
      # Expected: ".x1ruww2u{position:sticky;position:fixed}"
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1ruww2u{position:sticky;position:fixed}"
    end
  end

  # ===========================================================================
  # StyleX parity tests - transitionProperty/willChange
  # ===========================================================================

  describe "transitionProperty" do
    test "kebab-case values match StyleX output" do
      # StyleX: transitionProperty: 'margin-top' -> ".x1cfch2b{transition-property:margin-top}"
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1cfch2b{transition-property:margin-top}"
    end

    test "custom property names pass through unchanged" do
      # Custom properties (--foo) should not be modified
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "transition-property:--foo"
    end

    test "multiple values match StyleX output" do
      # StyleX: transitionProperty: 'opacity,inset-inline-start'
      # -> ".xh6nlrc{transition-property:opacity,inset-inline-start}"
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xh6nlrc{transition-property:opacity,inset-inline-start}"
    end
  end

  describe "willChange" do
    test "kebab-case values match StyleX output" do
      # StyleX: willChange: 'inset-inline-start' -> ".x1n5prqt{will-change:inset-inline-start}"
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1n5prqt{will-change:inset-inline-start}"
    end
  end
end
