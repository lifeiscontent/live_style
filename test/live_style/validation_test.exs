defmodule LiveStyle.ValidationTest do
  @moduledoc """
  Tests for LiveStyle validation and error handling.

  These tests verify that LiveStyle raises appropriate errors for:
  - Invalid constant references
  - Invalid when conditions
  - Invalid theme references
  - Invalid position_try references
  - Invalid view_transition references

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/validation-*.js
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Invalid constant references
  # ===========================================================================

  describe "css_const validation" do
    test "raises error for unknown constant reference" do
      assert_raise ArgumentError, ~r/Unknown constant/, fn ->
        defmodule UnknownConstModule do
          use LiveStyle

          # Try to reference a constant that doesn't exist
          @nonexistent css_const({SomeNonexistentModule, :namespace, :name})
        end
      end
    end
  end

  # ===========================================================================
  # Invalid when conditions
  # ===========================================================================

  describe "css_when validation" do
    test "raises error for pseudo-elements in ancestor selector" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/, fn ->
        LiveStyle.When.ancestor("::before", %{color: "red"})
      end
    end

    test "raises error for pseudo-elements in descendant selector" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/, fn ->
        LiveStyle.When.descendant("::after", %{color: "blue"})
      end
    end

    test "raises error for invalid pseudo selector format" do
      assert_raise ArgumentError, ~r/Pseudo selector must start with ':'/, fn ->
        LiveStyle.When.ancestor("hover", %{color: "red"})
      end
    end
  end

  # ===========================================================================
  # Runtime reference validation
  # ===========================================================================

  describe "LiveStyle.Theme.lookup!/3 validation" do
    defmodule ThemeVarsModule do
      use LiveStyle

      css_vars(:colors, primary: "blue")
    end

    defmodule ValidThemeModule do
      use LiveStyle

      css_theme({ThemeVarsModule, :colors}, :dark, primary: "lightblue")
    end

    test "raises error for unknown theme reference" do
      assert_raise ArgumentError, ~r/Unknown theme/, fn ->
        LiveStyle.Theme.lookup!(ValidThemeModule, :colors, :nonexistent)
      end
    end
  end

  describe "LiveStyle.PositionTry.lookup!/2 validation" do
    defmodule ValidPositionTryModule do
      use LiveStyle

      css_position_try(:flip_block, margin_block: "5px")
    end

    test "raises error for unknown position_try reference" do
      assert_raise ArgumentError, ~r/Unknown position_try/, fn ->
        LiveStyle.PositionTry.lookup!(ValidPositionTryModule, :nonexistent)
      end
    end
  end

  describe "LiveStyle.ViewTransition.lookup!/2 validation" do
    defmodule ValidViewTransitionModule do
      use LiveStyle

      css_view_transition(:slide)
    end

    test "raises error for unknown view_transition reference" do
      assert_raise ArgumentError, ~r/Unknown view_transition/, fn ->
        LiveStyle.ViewTransition.lookup!(ValidViewTransitionModule, :nonexistent)
      end
    end
  end

  # ===========================================================================
  # css_vars validation
  # ===========================================================================

  describe "css_vars validation" do
    defmodule ValidVarsModule do
      use LiveStyle

      css_vars(:valid,
        simple: "10px",
        conditional: %{
          :default => "blue",
          "@media (prefers-color-scheme: dark)" => "lightblue"
        }
      )
    end

    test "valid css_vars are stored in manifest" do
      manifest = get_manifest()

      simple_key = "LiveStyle.ValidationTest.ValidVarsModule.valid.simple"
      conditional_key = "LiveStyle.ValidationTest.ValidVarsModule.valid.conditional"

      assert manifest.vars[simple_key] != nil
      assert manifest.vars[conditional_key] != nil
    end

    test "vars have correct css_name format" do
      manifest = get_manifest()
      var = manifest.vars["LiveStyle.ValidationTest.ValidVarsModule.valid.simple"]

      # CSS variable names should start with --
      assert var.css_name =~ ~r/^--/
    end
  end

  # ===========================================================================
  # css_keyframes validation
  # ===========================================================================

  describe "css_keyframes validation" do
    defmodule ValidKeyframesModule do
      use LiveStyle

      css_keyframes(:spin,
        from: [transform: "rotate(0deg)"],
        to: [transform: "rotate(360deg)"]
      )
    end

    test "valid keyframes are stored in manifest" do
      manifest = get_manifest()
      key = "LiveStyle.ValidationTest.ValidKeyframesModule.spin"

      assert manifest.keyframes[key] != nil
    end

    test "keyframes have css_name" do
      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.ValidationTest.ValidKeyframesModule.spin"]

      assert keyframes.css_name =~ ~r/^[a-zA-Z]/
    end
  end

  # ===========================================================================
  # css_class value validation (StyleX parity)
  # Reference: validation-stylex-create-test.js lines 247-378
  # ===========================================================================

  describe "css_class value validation" do
    test "raises error for boolean true value" do
      # StyleX: 'invalid value: boolean' - throws messages.ILLEGAL_PROP_VALUE
      assert_raise ArgumentError, ~r/Invalid property value: boolean/, fn ->
        defmodule BooleanTrueModule do
          use LiveStyle

          css_class(:test, color: true)
        end
      end
    end

    test "raises error for boolean false value" do
      assert_raise ArgumentError, ~r/Invalid property value: boolean/, fn ->
        defmodule BooleanFalseModule do
          use LiveStyle

          css_class(:test, display: false)
        end
      end
    end

    test "raises error for array containing objects" do
      # StyleX: 'invalid value: array of objects' - throws "A style array value can only contain strings or numbers."
      assert_raise ArgumentError, ~r/style array.*can only contain strings or numbers/, fn ->
        defmodule ArrayWithObjectModule do
          use LiveStyle

          css_class(:test, transition_duration: [[], %{}])
        end
      end
    end

    test "raises error for array containing boolean" do
      assert_raise ArgumentError, ~r/style array.*can only contain strings or numbers/, fn ->
        defmodule ArrayWithBooleanModule do
          use LiveStyle

          css_class(:test, transition_duration: [true, "0.5s"])
        end
      end
    end

    test "allows number values" do
      # StyleX: 'valid value: number' - should not throw
      defmodule NumberValueModule do
        use LiveStyle

        css_class(:test, padding: 5)
      end

      manifest = get_manifest()
      assert manifest.rules["LiveStyle.ValidationTest.NumberValueModule.test"] != nil
    end

    test "allows string values" do
      # StyleX: 'valid value: string' - should not throw
      defmodule StringValueModule do
        use LiveStyle

        css_class(:test, background_color: "red")
      end

      manifest = get_manifest()
      assert manifest.rules["LiveStyle.ValidationTest.StringValueModule.test"] != nil
    end

    test "allows nil values (StyleX null behavior)" do
      # StyleX allows null to unset properties
      defmodule NilValueModule do
        use LiveStyle

        css_class(:test, color: nil)
      end

      manifest = get_manifest()
      assert manifest.rules["LiveStyle.ValidationTest.NilValueModule.test"] != nil
    end

    test "allows array of numbers for fallback values" do
      # StyleX: 'valid value: array of numbers' - should not throw
      defmodule ArrayNumbersModule do
        use LiveStyle

        css_class(:test, transition_duration: [500])
      end

      manifest = get_manifest()
      assert manifest.rules["LiveStyle.ValidationTest.ArrayNumbersModule.test"] != nil
    end

    test "allows array of strings for fallback values" do
      # StyleX: 'valid value: array of strings' - should not throw
      defmodule ArrayStringsModule do
        use LiveStyle

        css_class(:test, transition_duration: ["0.5s"])
      end

      manifest = get_manifest()
      assert manifest.rules["LiveStyle.ValidationTest.ArrayStringsModule.test"] != nil
    end
  end

  # ===========================================================================
  # css_keyframes value validation
  # Reference: validation-stylex-keyframes-test.js
  # ===========================================================================

  describe "css_keyframes value validation" do
    test "raises error for non-object keyframe value" do
      # StyleX: 'only argument must be an object of objects' - throws messages.NON_OBJECT_KEYFRAME
      assert_raise ArgumentError, ~r/Keyframe value must be a keyword list or map/, fn ->
        defmodule BooleanKeyframeModule do
          use LiveStyle

          css_keyframes(:invalid, from: false)
        end
      end
    end

    test "allows percentage-based keyframes" do
      # StyleX: allows '0%', '50%', '100%' as keyframe selectors
      defmodule PercentageKeyframesModule do
        use LiveStyle

        css_keyframes(:fade,
          "0%": [opacity: 0],
          "50%": [opacity: 0.5],
          "100%": [opacity: 1]
        )
      end

      manifest = get_manifest()
      assert manifest.keyframes["LiveStyle.ValidationTest.PercentageKeyframesModule.fade"] != nil
    end

    test "allows from/to keyframes" do
      defmodule FromToKeyframesModule do
        use LiveStyle

        css_keyframes(:slide,
          from: [transform: "translateX(0)"],
          to: [transform: "translateX(100px)"]
        )
      end

      manifest = get_manifest()
      assert manifest.keyframes["LiveStyle.ValidationTest.FromToKeyframesModule.slide"] != nil
    end
  end

  # ===========================================================================
  # css_theme validation
  # ===========================================================================

  describe "css_theme validation" do
    defmodule ThemeBaseVars do
      use LiveStyle

      css_vars(:base,
        color: "red",
        size: "10px"
      )
    end

    defmodule ValidThemeOverride do
      use LiveStyle

      css_theme({ThemeBaseVars, :base}, :override,
        color: "blue",
        size: "20px"
      )
    end

    test "theme overrides are stored in manifest" do
      manifest = get_manifest()
      key = "LiveStyle.ValidationTest.ValidThemeOverride.base.override"

      assert manifest.themes[key] != nil
    end

    test "theme has overrides map" do
      manifest = get_manifest()
      theme = manifest.themes["LiveStyle.ValidationTest.ValidThemeOverride.base.override"]

      assert is_map(theme.overrides)
      assert map_size(theme.overrides) > 0
    end
  end
end
