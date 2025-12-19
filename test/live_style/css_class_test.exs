defmodule LiveStyle.CSSClassTest do
  @moduledoc """
  Tests for basic css_class functionality.

  These tests mirror StyleX's transform-stylex-create-test.js to ensure
  LiveStyle generates equivalent CSS output and metadata.
  """
  use LiveStyle.TestCase, async: true

  # Test modules must be defined at compile time
  defmodule BasicStyles do
    use LiveStyle

    css_class(:root,
      background_color: "red",
      color: "blue"
    )
  end

  defmodule MultipleRules do
    use LiveStyle

    css_class(:root, background_color: "red")
    css_class(:other, color: "blue")
    css_class(:bar_baz, color: "green")
  end

  defmodule CustomProperties do
    use LiveStyle

    # Custom properties (CSS variables) should:
    # - Not modify casing
    # - Not add units to unitless values
    css_class(:root,
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
    css_class(:user_select, user_select: "none")
  end

  # ===========================================================================
  # StyleX parity tests - array fallbacks
  # ===========================================================================

  defmodule ArrayFallbackStyles do
    use LiveStyle

    # StyleX test: position: ['sticky', 'fixed'] -> ".x1ruww2u{position:sticky;position:fixed}"
    css_class(:position_fallback, position: ["sticky", "fixed"])
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
    css_class(:kebab_case, transition_property: "margin-top")

    # Custom property names (--foo) pass through unchanged
    css_class(:custom_prop, transition_property: "--foo")

    # Multiple values in kebab-case
    # StyleX equivalent: transitionProperty: 'opacity, inset-inline-start'
    css_class(:multi_value, transition_property: "opacity,inset-inline-start")
  end

  defmodule WillChangeStyles do
    use LiveStyle

    # Idiomatic Elixir: use kebab-case strings
    # StyleX equivalent: willChange: 'inset-inline-start'
    css_class(:kebab_case, will_change: "inset-inline-start")
  end

  describe "static styles" do
    test "generates CSS for basic style object" do
      # StyleX test: "style object"
      # Input: { backgroundColor: 'red', color: 'blue' }
      # Expected metadata:
      #   ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      #   ["xju2f9n", {ltr: ".xju2f9n{color:blue}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.BasicStyles.root"]

      assert rule != nil

      # Check background-color metadata
      bg_meta = rule.atomic_classes["background-color"]
      assert bg_meta.class == "xrkmrrc"
      assert bg_meta.ltr == ".xrkmrrc{background-color:red}"
      assert bg_meta.rtl == nil
      assert bg_meta.priority == 3000

      # Check color metadata
      color_meta = rule.atomic_classes["color"]
      assert color_meta.class == "xju2f9n"
      assert color_meta.ltr == ".xju2f9n{color:blue}"
      assert color_meta.rtl == nil
      assert color_meta.priority == 3000
    end

    test "generates correct class string for properties" do
      class = LiveStyle.get_css_class(BasicStyles, [:root])

      # Should have class names for both properties
      # StyleX produces: "xrkmrrc xju2f9n"
      assert class =~ "xrkmrrc"
      assert class =~ "xju2f9n"
    end

    test "multiple style objects generate unique class names" do
      # StyleX test: "style object (multiple)"
      manifest = get_manifest()

      root_rule = manifest.rules["LiveStyle.CSSRuleTest.MultipleRules.root"]
      other_rule = manifest.rules["LiveStyle.CSSRuleTest.MultipleRules.other"]
      bar_baz_rule = manifest.rules["LiveStyle.CSSRuleTest.MultipleRules.bar_baz"]

      # root: backgroundColor: 'red'
      assert root_rule.atomic_classes["background-color"].class == "xrkmrrc"
      assert root_rule.atomic_classes["background-color"].ltr == ".xrkmrrc{background-color:red}"
      assert root_rule.atomic_classes["background-color"].priority == 3000

      # other: color: 'blue'
      assert other_rule.atomic_classes["color"].class == "xju2f9n"
      assert other_rule.atomic_classes["color"].ltr == ".xju2f9n{color:blue}"
      assert other_rule.atomic_classes["color"].priority == 3000

      # bar_baz: color: 'green'
      assert bar_baz_rule.atomic_classes["color"].class == "x1prwzq3"
      assert bar_baz_rule.atomic_classes["color"].ltr == ".x1prwzq3{color:green}"
      assert bar_baz_rule.atomic_classes["color"].priority == 3000
    end

    test "custom properties preserve casing and don't add units" do
      # StyleX test: "style object with custom properties"
      # Custom properties should:
      # - Not modify casing (--otherColor stays --otherColor)
      # - Not add units to numeric values (10 stays 10, not 10px)
      # Expected priority: 1 (custom properties have lowest priority)

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.CustomProperties.root"]

      # --background-color: red
      bg_meta = rule.atomic_classes["--background-color"]
      assert bg_meta.ltr == ".xgau0yw{--background-color:red}"
      assert bg_meta.priority == 1

      # --otherColor: green (casing preserved)
      other_meta = rule.atomic_classes["--otherColor"]
      assert other_meta.ltr == ".x1p9b6ba{--otherColor:green}"
      assert other_meta.priority == 1

      # --foo: 10 (no px added)
      foo_meta = rule.atomic_classes["--foo"]
      assert foo_meta.ltr == ".x40g909{--foo:10}"
      assert foo_meta.priority == 1
    end
  end

  describe "priority levels" do
    # StyleX priority levels (from metadata):
    # - Custom properties: 1
    # - Shorthands of shorthands (margin, padding): 1000
    # - Shorthands of longhands (borderColor): 2000
    # - Default longhands: 3000
    # - Physical longhands: 4000

    test "custom properties have lowest priority (1)" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.CustomProperties.root"]

      # All custom property rules should have priority 1
      for {prop, meta} <- rule.atomic_classes do
        assert String.starts_with?(prop, "--")

        assert meta.priority == 1,
               "Custom property #{prop} should have priority 1, got #{meta.priority}"
      end
    end

    test "regular longhands have priority 3000" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.BasicStyles.root"]

      # color and background-color are both longhands with priority 3000
      assert rule.atomic_classes["color"].priority == 3000
      assert rule.atomic_classes["background-color"].priority == 3000
    end
  end

  # ===========================================================================
  # StyleX parity tests - vendor prefix properties
  # ===========================================================================

  describe "vendor prefix properties" do
    test "userSelect: 'none' generates correct class and CSS" do
      # StyleX test: transform-stylex-create-test.js
      # Input: { userSelect: 'none' }
      # Expected: ["x87ps6o", {ltr: ".x87ps6o{user-select:none}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.VendorPrefixStyles.user_select"]

      user_select_meta = rule.atomic_classes["user-select"]
      assert user_select_meta.class == "x87ps6o"
      assert user_select_meta.ltr == ".x87ps6o{user-select:none}"
      assert user_select_meta.rtl == nil
      assert user_select_meta.priority == 3000
    end
  end

  # ===========================================================================
  # StyleX parity tests - array fallbacks
  # ===========================================================================

  describe "array fallbacks" do
    test "position: ['sticky', 'fixed'] generates fallback declarations" do
      # StyleX test: transform-stylex-create-test.js "use array (fallbacks)"
      # Input: { position: ['sticky', 'fixed'] }
      # Expected: ["x1ruww2u", {ltr: ".x1ruww2u{position:sticky;position:fixed}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.ArrayFallbackStyles.position_fallback"]

      position_meta = rule.atomic_classes["position"]
      assert position_meta.class == "x1ruww2u"
      assert position_meta.ltr == ".x1ruww2u{position:sticky;position:fixed}"
      assert position_meta.rtl == nil
      assert position_meta.priority == 3000
    end
  end

  # ===========================================================================
  # StyleX parity tests - transitionProperty/willChange
  # ===========================================================================

  describe "transitionProperty" do
    test "kebab-case values match StyleX output" do
      # StyleX: transitionProperty: 'margin-top' -> ".x1cfch2b{transition-property:margin-top}"
      # LiveStyle: transition_property: "margin-top" -> ".x1cfch2b{transition-property:margin-top}"

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.TransitionPropertyStyles.kebab_case"]

      tp_meta = rule.atomic_classes["transition-property"]
      assert tp_meta.class == "x1cfch2b"
      assert tp_meta.ltr == ".x1cfch2b{transition-property:margin-top}"
      assert tp_meta.priority == 3000
    end

    test "custom property names pass through unchanged" do
      # Custom properties (--foo) should not be modified
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.TransitionPropertyStyles.custom_prop"]

      tp_meta = rule.atomic_classes["transition-property"]
      assert tp_meta.ltr =~ "transition-property:--foo"
    end

    test "multiple values match StyleX output" do
      # StyleX: transitionProperty: 'opacity,inset-inline-start'
      # -> ".xh6nlrc{transition-property:opacity,inset-inline-start}"

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.TransitionPropertyStyles.multi_value"]

      tp_meta = rule.atomic_classes["transition-property"]
      assert tp_meta.class == "xh6nlrc"
      assert tp_meta.ltr == ".xh6nlrc{transition-property:opacity,inset-inline-start}"
    end
  end

  describe "willChange" do
    test "kebab-case values match StyleX output" do
      # StyleX: willChange: 'inset-inline-start' -> ".x1n5prqt{will-change:inset-inline-start}"
      # LiveStyle: will_change: "inset-inline-start" -> ".x1n5prqt{will-change:inset-inline-start}"

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.CSSRuleTest.WillChangeStyles.kebab_case"]

      wc_meta = rule.atomic_classes["will-change"]
      assert wc_meta.class == "x1n5prqt"
      assert wc_meta.ltr == ".x1n5prqt{will-change:inset-inline-start}"
      assert wc_meta.priority == 3000
    end
  end
end
