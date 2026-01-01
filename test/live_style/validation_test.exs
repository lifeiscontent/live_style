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
  use LiveStyle.TestCase

  alias LiveStyle.Compiler.Class

  # ===========================================================================
  # Invalid constant references
  # ===========================================================================

  describe "const validation" do
    test "raises error for unknown constant reference" do
      assert_raise ArgumentError, ~r/Constant not found/, fn ->
        defmodule UnknownConstModule do
          use LiveStyle

          # Try to reference a constant that doesn't exist
          @nonexistent const({SomeNonexistentModule, :name})
        end
      end
    end
  end

  # ===========================================================================
  # Invalid when conditions
  # ===========================================================================

  describe "when validation" do
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

  describe "LiveStyle.Theme.lookup!/1 validation" do
    defmodule ThemeVarsModule do
      use LiveStyle

      vars(primary: "blue")

      theme(:dark, primary: "lightblue")
    end

    test "raises error for unknown theme reference" do
      assert_raise ArgumentError, ~r/Theme not found/, fn ->
        LiveStyle.Theme.lookup!({ThemeVarsModule, :nonexistent})
      end
    end
  end

  describe "LiveStyle.PositionTry.lookup!/1 validation" do
    defmodule ValidPositionTryModule do
      use LiveStyle

      position_try(:flip_block, margin_block: "5px")
    end

    test "raises error for unknown position_try reference" do
      assert_raise ArgumentError, ~r/Position-try not found/, fn ->
        LiveStyle.PositionTry.lookup!({ValidPositionTryModule, :nonexistent})
      end
    end
  end

  describe "LiveStyle.ViewTransition.lookup!/1 validation" do
    defmodule ValidViewTransitionModule do
      use LiveStyle

      view_transition_class(:slide, old: [opacity: "0"], new: [opacity: "1"])
    end

    test "raises error for unknown view_transition reference" do
      assert_raise ArgumentError, ~r/View transition not found/, fn ->
        LiveStyle.ViewTransition.lookup!({ValidViewTransitionModule, :nonexistent})
      end
    end
  end

  # ===========================================================================
  # vars validation
  # ===========================================================================

  describe "vars validation" do
    defmodule ValidVarsModule do
      use LiveStyle

      vars(
        simple: "10px",
        conditional: [
          default: "blue",
          "@media (prefers-color-scheme: dark)": "lightblue"
        ]
      )
    end

    test "valid vars are stored in manifest" do
      assert LiveStyle.Vars.lookup!({ValidVarsModule, :simple}) != nil
      assert LiveStyle.Vars.lookup!({ValidVarsModule, :conditional}) != nil
    end

    test "vars have correct ident format" do
      var = LiveStyle.Vars.lookup!({ValidVarsModule, :simple})

      # CSS variable names should start with --
      assert var.ident =~ ~r/^--/
    end
  end

  # ===========================================================================
  # keyframes validation
  # ===========================================================================

  describe "keyframes validation" do
    defmodule ValidKeyframesModule do
      use LiveStyle

      keyframes(:spin,
        from: [transform: "rotate(0deg)"],
        to: [transform: "rotate(360deg)"]
      )
    end

    test "valid keyframes are stored in manifest" do
      assert LiveStyle.Keyframes.lookup!({ValidKeyframesModule, :spin}) != nil
    end

    test "keyframes have ident" do
      keyframes = LiveStyle.Keyframes.lookup!({ValidKeyframesModule, :spin})

      assert keyframes.ident =~ ~r/^[a-zA-Z]/
    end
  end

  # ===========================================================================
  # class value validation (StyleX parity)
  # Reference: validation-stylex-create-test.js lines 247-378
  # ===========================================================================

  describe "class value validation" do
    test "raises error for boolean true value" do
      # StyleX: 'invalid value: boolean' - throws messages.ILLEGAL_PROP_VALUE
      assert_raise ArgumentError, ~r/Invalid property value: boolean/, fn ->
        defmodule BooleanTrueModule do
          use LiveStyle

          class(:test, color: true)
        end
      end
    end

    test "raises error for boolean false value" do
      assert_raise ArgumentError, ~r/Invalid property value: boolean/, fn ->
        defmodule BooleanFalseModule do
          use LiveStyle

          class(:test, display: false)
        end
      end
    end

    test "raises error for array containing objects" do
      # StyleX: 'invalid value: array of objects' - throws "A style array value can only contain strings or numbers."
      assert_raise ArgumentError, ~r/style array.*can only contain strings or numbers/, fn ->
        defmodule ArrayWithObjectModule do
          use LiveStyle

          class(:test, transition_duration: [[], %{}])
        end
      end
    end

    test "raises error for array containing boolean" do
      assert_raise ArgumentError, ~r/style array.*can only contain strings or numbers/, fn ->
        defmodule ArrayWithBooleanModule do
          use LiveStyle

          class(:test, transition_duration: [true, "0.5s"])
        end
      end
    end

    test "raises error for tuple value (legacy conditional shorthand)" do
      assert_raise ArgumentError, ~r/tuple values are not supported/, fn ->
        defmodule TupleValueModule do
          use LiveStyle

          class(:test, color: {":hover", "red"})
        end
      end
    end

    test "raises error for legacy nested at-rule object syntax" do
      # Now raises a general "maps not supported" error since we reject maps entirely
      assert_raise ArgumentError, ~r/Maps are not supported/, fn ->
        defmodule LegacyAtRuleObjectModule do
          use LiveStyle

          class(:test, %{"@media (min-width: 768px)" => %{color: "red"}})
        end
      end
    end

    test "allows number values" do
      # StyleX: 'valid value: number' - should not throw
      defmodule NumberValueModule do
        use LiveStyle

        class(:test, padding: 5)
      end

      assert Class.lookup!({NumberValueModule, :test}) != nil
    end

    test "allows string values" do
      # StyleX: 'valid value: string' - should not throw
      defmodule StringValueModule do
        use LiveStyle

        class(:test, background_color: "red")
      end

      assert Class.lookup!({StringValueModule, :test}) != nil
    end

    test "allows nil values (StyleX null behavior)" do
      # StyleX allows null to unset properties
      defmodule NilValueModule do
        use LiveStyle

        class(:test, color: nil)
      end

      assert Class.lookup!({NilValueModule, :test}) != nil
    end

    test "allows array of numbers for fallback values" do
      # StyleX: 'valid value: array of numbers' - should not throw
      defmodule ArrayNumbersModule do
        use LiveStyle

        class(:test, transition_duration: [500])
      end

      assert Class.lookup!({ArrayNumbersModule, :test}) != nil
    end

    test "allows array of strings for fallback values" do
      # StyleX: 'valid value: array of strings' - should not throw
      defmodule ArrayStringsModule do
        use LiveStyle

        class(:test, transition_duration: ["0.5s"])
      end

      assert Class.lookup!({ArrayStringsModule, :test}) != nil
    end
  end

  # ===========================================================================
  # keyframes value validation
  # Reference: validation-stylex-keyframes-test.js
  # ===========================================================================

  describe "keyframes value validation" do
    test "raises error for non-object keyframe value" do
      # StyleX: 'only argument must be an object of objects' - throws messages.NON_OBJECT_KEYFRAME
      assert_raise ArgumentError, ~r/Keyframe value must be a keyword list/, fn ->
        defmodule BooleanKeyframeModule do
          use LiveStyle

          keyframes(:invalid, from: false)
        end
      end
    end

    test "allows percentage-based keyframes" do
      # StyleX: allows '0%', '50%', '100%' as keyframe selectors
      defmodule PercentageKeyframesModule do
        use LiveStyle

        keyframes(:fade,
          "0%": [opacity: 0],
          "50%": [opacity: 0.5],
          "100%": [opacity: 1]
        )
      end

      assert LiveStyle.Keyframes.lookup!({PercentageKeyframesModule, :fade}) != nil
    end

    test "allows from/to keyframes" do
      defmodule FromToKeyframesModule do
        use LiveStyle

        keyframes(:slide,
          from: [transform: "translateX(0)"],
          to: [transform: "translateX(100px)"]
        )
      end

      assert LiveStyle.Keyframes.lookup!({FromToKeyframesModule, :slide}) != nil
    end
  end

  # ===========================================================================
  # theme validation
  # ===========================================================================

  describe "theme validation" do
    defmodule ThemeBaseVars do
      use LiveStyle

      vars(
        color: "red",
        size: "10px"
      )

      theme(:override,
        color: "blue",
        size: "20px"
      )
    end

    test "theme overrides are stored in manifest" do
      assert LiveStyle.Theme.lookup!({ThemeBaseVars, :override}) != nil
    end

    test "theme has overrides list" do
      theme = LiveStyle.Theme.lookup!({ThemeBaseVars, :override})

      assert is_list(theme.overrides)
      assert not Enum.empty?(theme.overrides)
    end
  end
end
