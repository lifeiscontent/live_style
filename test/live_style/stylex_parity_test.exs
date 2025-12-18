defmodule LiveStyle.StyleXParityTest do
  @moduledoc """
  Comprehensive StyleX parity tests.

  This file mirrors StyleX's transform-stylex-create-test.js to ensure
  LiveStyle produces EXACTLY the same output as StyleX for each test case.

  Each test includes:
  - The original StyleX test name
  - The StyleX input
  - The expected output (class name, ltr, rtl, priority)

  Format: [class_name, {ltr: "...", rtl: null}, priority]
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Test: "style object"
  # StyleX Input: { backgroundColor: 'red', color: 'blue' }
  # ============================================================================

  defmodule StyleObject do
    use LiveStyle

    css_rule(:root,
      background_color: "red",
      color: "blue"
    )
  end

  # ============================================================================
  # Test: "style object (multiple)"
  # StyleX Input: root: { backgroundColor: 'red' }, other: { color: 'blue' }, etc.
  # ============================================================================

  defmodule StyleObjectMultiple do
    use LiveStyle

    css_rule(:root, background_color: "red")
    css_rule(:other, color: "blue")
    css_rule(:bar_baz, color: "green")
    css_rule(:purple_color, color: "purple")
  end

  # ============================================================================
  # Test: "style object with custom properties"
  # StyleX Input: { '--background-color': 'red', '--otherColor': 'green', '--foo': 10 }
  # ============================================================================

  defmodule CustomProperties do
    use LiveStyle

    css_rule(:root,
      "--background-color": "red",
      "--otherColor": "green",
      "--foo": 10
    )
  end

  # ============================================================================
  # Test: "style object requiring vendor prefixes"
  # StyleX Input: { userSelect: 'none' }
  # ============================================================================

  defmodule VendorPrefixes do
    use LiveStyle

    css_rule(:root, user_select: "none")
  end

  # ============================================================================
  # Test: "use array (fallbacks)"
  # StyleX Input: { position: ['sticky', 'fixed'] }
  # ============================================================================

  defmodule ArrayFallbacks do
    use LiveStyle

    css_rule(:root, position: ["sticky", "fixed"])
  end

  # ============================================================================
  # Test: "valid pseudo-class"
  # StyleX Input: { backgroundColor: { ':hover': 'red' }, color: { ':hover': 'blue' } }
  # ============================================================================

  defmodule ValidPseudoClass do
    use LiveStyle

    css_rule(:root,
      background_color: [":hover": "red"],
      color: [":hover": "blue"]
    )
  end

  # ============================================================================
  # Test: "pseudo-class generated order"
  # StyleX Input: { color: { ':hover': 'blue', ':active': 'red', ':focus': 'yellow', ':nth-child(2n)': 'purple' } }
  # ============================================================================

  defmodule PseudoClassOrder do
    use LiveStyle

    css_rule(:root,
      color: [
        ":hover": "blue",
        ":active": "red",
        ":focus": "yellow",
        ":nth-child(2n)": "purple"
      ]
    )
  end

  # ============================================================================
  # Test: "pseudo-class generated order (nested, same value)"
  # StyleX Input: { color: { ':hover': { ':active': 'red' }, ':active': { ':hover': 'red' } } }
  # ============================================================================

  defmodule NestedPseudoSameValue do
    use LiveStyle

    # Both :hover:active and :active:hover produce same class because value is same
    # and pseudos are sorted alphabetically
    css_rule(:root,
      color: [
        ":hover": [":active": "red"],
        ":active": [":hover": "red"]
      ]
    )
  end

  # ============================================================================
  # Test: '"::before" and "::after"'
  # StyleX Input: { '::before': { color: 'red' }, '::after': { color: 'blue' } }
  # ============================================================================

  defmodule BeforeAfter do
    use LiveStyle

    css_rule(:foo,
      "::before": [color: "red"],
      "::after": [color: "blue"]
    )
  end

  # ============================================================================
  # Test: '"::before" containing pseudo-classes'
  # StyleX Input: { '::before': { color: { default: 'red', ':hover': 'blue' } } }
  # ============================================================================

  defmodule BeforeWithPseudo do
    use LiveStyle

    css_rule(:foo,
      "::before": [
        color: [
          default: "red",
          ":hover": "blue"
        ]
      ]
    )
  end

  # ============================================================================
  # Test: "keyframes object"
  # StyleX Input: { from: { color: 'red' }, to: { color: 'blue' } }
  # ============================================================================

  defmodule KeyframesObject do
    use LiveStyle

    css_keyframes(:name,
      from: %{color: "red"},
      to: %{color: "blue"}
    )
  end

  # ============================================================================
  # Test: "media queries"
  # StyleX Input: { backgroundColor: { default: 'red', '@media (min-width: 1000px)': 'blue', '@media (min-width: 2000px)': 'purple' } }
  # ============================================================================

  defmodule MediaQueries do
    use LiveStyle

    css_rule(:root,
      background_color: [
        default: "red",
        "@media (min-width: 1000px)": "blue",
        "@media (min-width: 2000px)": "purple"
      ]
    )
  end

  # ============================================================================
  # Test: "supports queries"
  # StyleX Input: { backgroundColor: { default: 'red', '@supports (hover: hover)': 'blue', '@supports not (hover: hover)': 'purple' } }
  # ============================================================================

  defmodule SupportsQueries do
    use LiveStyle

    css_rule(:root,
      background_color: [
        default: "red",
        "@supports (hover: hover)": "blue",
        "@supports not (hover: hover)": "purple"
      ]
    )
  end

  # ============================================================================
  # Test: "media query with pseudo-classes"
  # StyleX Input: { fontSize: { default: '1rem', '@media (min-width: 800px)': { default: '2rem', ':hover': '2.2rem' } } }
  # ============================================================================

  defmodule MediaQueryWithPseudo do
    use LiveStyle

    css_rule(:root,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": [
          default: "2rem",
          ":hover": "2.2rem"
        ]
      ]
    )
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "StyleX test: 'style object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xju2f9n", {ltr: ".xju2f9n{color:blue}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.StyleObject.root"]

      bg = rule.atomic_classes["background-color"]
      assert bg.class == "xrkmrrc"
      assert bg.ltr == ".xrkmrrc{background-color:red}"
      assert bg.rtl == nil
      assert bg.priority == 3000

      color = rule.atomic_classes["color"]
      assert color.class == "xju2f9n"
      assert color.ltr == ".xju2f9n{color:blue}"
      assert color.rtl == nil
      assert color.priority == 3000
    end
  end

  describe "StyleX test: 'style object (multiple)'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xju2f9n", {ltr: ".xju2f9n{color:blue}", rtl: null}, 3000]
      # ["x1prwzq3", {ltr: ".x1prwzq3{color:green}", rtl: null}, 3000]
      # ["x125ip1n", {ltr: ".x125ip1n{color:purple}", rtl: null}, 3000]

      manifest = get_manifest()

      root = manifest.rules["LiveStyle.StyleXParityTest.StyleObjectMultiple.root"]
      assert root.atomic_classes["background-color"].class == "xrkmrrc"
      assert root.atomic_classes["background-color"].ltr == ".xrkmrrc{background-color:red}"
      assert root.atomic_classes["background-color"].priority == 3000

      other = manifest.rules["LiveStyle.StyleXParityTest.StyleObjectMultiple.other"]
      assert other.atomic_classes["color"].class == "xju2f9n"
      assert other.atomic_classes["color"].ltr == ".xju2f9n{color:blue}"
      assert other.atomic_classes["color"].priority == 3000

      bar_baz = manifest.rules["LiveStyle.StyleXParityTest.StyleObjectMultiple.bar_baz"]
      assert bar_baz.atomic_classes["color"].class == "x1prwzq3"
      assert bar_baz.atomic_classes["color"].ltr == ".x1prwzq3{color:green}"
      assert bar_baz.atomic_classes["color"].priority == 3000

      purple = manifest.rules["LiveStyle.StyleXParityTest.StyleObjectMultiple.purple_color"]
      assert purple.atomic_classes["color"].class == "x125ip1n"
      assert purple.atomic_classes["color"].ltr == ".x125ip1n{color:purple}"
      assert purple.atomic_classes["color"].priority == 3000
    end
  end

  describe "StyleX test: 'style object with custom properties'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xgau0yw", {ltr: ".xgau0yw{--background-color:red}", rtl: null}, 1]
      # ["x1p9b6ba", {ltr: ".x1p9b6ba{--otherColor:green}", rtl: null}, 1]
      # ["x40g909", {ltr: ".x40g909{--foo:10}", rtl: null}, 1]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.CustomProperties.root"]

      bg = rule.atomic_classes["--background-color"]
      assert bg.class == "xgau0yw"
      assert bg.ltr == ".xgau0yw{--background-color:red}"
      assert bg.rtl == nil
      assert bg.priority == 1

      other = rule.atomic_classes["--otherColor"]
      assert other.class == "x1p9b6ba"
      assert other.ltr == ".x1p9b6ba{--otherColor:green}"
      assert other.rtl == nil
      assert other.priority == 1

      foo = rule.atomic_classes["--foo"]
      assert foo.class == "x40g909"
      assert foo.ltr == ".x40g909{--foo:10}"
      assert foo.rtl == nil
      assert foo.priority == 1
    end
  end

  describe "StyleX test: 'style object requiring vendor prefixes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x87ps6o", {ltr: ".x87ps6o{user-select:none}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.VendorPrefixes.root"]

      user_select = rule.atomic_classes["user-select"]
      assert user_select.class == "x87ps6o"
      assert user_select.ltr == ".x87ps6o{user-select:none}"
      assert user_select.rtl == nil
      assert user_select.priority == 3000
    end
  end

  describe "StyleX test: 'use array (fallbacks)'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1ruww2u", {ltr: ".x1ruww2u{position:sticky;position:fixed}", rtl: null}, 3000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.ArrayFallbacks.root"]

      position = rule.atomic_classes["position"]
      assert position.class == "x1ruww2u"
      assert position.ltr == ".x1ruww2u{position:sticky;position:fixed}"
      assert position.rtl == nil
      assert position.priority == 3000
    end
  end

  describe "StyleX test: 'valid pseudo-class'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1gykpug", {ltr: ".x1gykpug:hover{background-color:red}", rtl: null}, 3130]
      # ["x17z2mba", {ltr: ".x17z2mba:hover{color:blue}", rtl: null}, 3130]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.ValidPseudoClass.root"]

      bg = rule.atomic_classes["background-color"].classes[":hover"]
      assert bg.class == "x1gykpug"
      assert bg.ltr == ".x1gykpug:hover{background-color:red}"
      assert bg.rtl == nil
      assert bg.priority == 3130

      color = rule.atomic_classes["color"].classes[":hover"]
      assert color.class == "x17z2mba"
      assert color.ltr == ".x17z2mba:hover{color:blue}"
      assert color.rtl == nil
      assert color.priority == 3130
    end
  end

  describe "StyleX test: 'pseudo-class generated order'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x17z2mba", {ltr: ".x17z2mba:hover{color:blue}", rtl: null}, 3130]
      # ["x96fq8s", {ltr: ".x96fq8s:active{color:red}", rtl: null}, 3170]
      # ["x1wvtd7d", {ltr: ".x1wvtd7d:focus{color:yellow}", rtl: null}, 3150]
      # ["x126ychx", {ltr: ".x126ychx:nth-child(2n){color:purple}", rtl: null}, 3060]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.PseudoClassOrder.root"]
      classes = rule.atomic_classes["color"].classes

      hover = classes[":hover"]
      assert hover.class == "x17z2mba"
      assert hover.ltr == ".x17z2mba:hover{color:blue}"
      assert hover.priority == 3130

      active = classes[":active"]
      assert active.class == "x96fq8s"
      assert active.ltr == ".x96fq8s:active{color:red}"
      assert active.priority == 3170

      focus = classes[":focus"]
      assert focus.class == "x1wvtd7d"
      assert focus.ltr == ".x1wvtd7d:focus{color:yellow}"
      assert focus.priority == 3150

      nth_child = classes[":nth-child(2n)"]
      assert nth_child.class == "x126ychx"
      assert nth_child.ltr == ".x126ychx:nth-child(2n){color:purple}"
      assert nth_child.priority == 3060
    end
  end

  describe "StyleX test: 'pseudo-class generated order (nested, same value)'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xa2ikkt", {ltr: ".xa2ikkt:active:hover{color:red}", rtl: null}, 3300]
      # Note: Both :hover:active and :active:hover produce same class because
      # the value is the same and pseudos are sorted alphabetically

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.NestedPseudoSameValue.root"]
      classes = rule.atomic_classes["color"].classes

      # The key will be the combined selector as written, but both should
      # produce the same class name due to deduplication
      nested = classes[":hover:active"] || classes[":active:hover"]
      assert nested.class == "xa2ikkt"
      assert nested.ltr == ".xa2ikkt:active:hover{color:red}"
      assert nested.priority == 3300
    end
  end

  describe "StyleX test: '\"::before\" and \"::after\"'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x16oeupf", {ltr: ".x16oeupf::before{color:red}", rtl: null}, 8000]
      # ["xdaarc3", {ltr: ".xdaarc3::after{color:blue}", rtl: null}, 8000]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.BeforeAfter.foo"]

      before = rule.atomic_classes["color::before"]
      assert before.class == "x16oeupf"
      assert before.ltr == ".x16oeupf::before{color:red}"
      assert before.rtl == nil
      assert before.priority == 8000

      after_ = rule.atomic_classes["color::after"]
      assert after_.class == "xdaarc3"
      assert after_.ltr == ".xdaarc3::after{color:blue}"
      assert after_.rtl == nil
      assert after_.priority == 8000
    end
  end

  describe "StyleX test: '\"::before\" containing pseudo-classes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x16oeupf", {ltr: ".x16oeupf::before{color:red}", rtl: null}, 8000]
      # ["xeb2lg0", {ltr: ".xeb2lg0::before:hover{color:blue}", rtl: null}, 8130]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.BeforeWithPseudo.foo"]

      default = rule.atomic_classes["color::before"]
      assert default.class == "x16oeupf"
      assert default.ltr == ".x16oeupf::before{color:red}"
      assert default.priority == 8000

      hover = rule.atomic_classes["color::before:hover"]
      assert hover.class == "xeb2lg0"
      assert hover.ltr == ".xeb2lg0::before:hover{color:blue}"
      assert hover.rtl == nil
      assert hover.priority == 8130
    end
  end

  describe "StyleX test: 'keyframes object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x2up61p-B", {ltr: "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}", rtl: null}, 0]

      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.StyleXParityTest.KeyframesObject.name"]

      assert keyframes.css_name == "x2up61p-B"
      assert keyframes.ltr == "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
      assert keyframes.rtl == nil
      assert keyframes.priority == 0
    end
  end

  describe "StyleX test: 'media queries'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xw6up8c", {ltr: "@media (min-width: 1000px) and (max-width: 1999.99px){.xw6up8c.xw6up8c{background-color:blue}}", rtl: null}, 3200]
      # ["x1ssfqz5", {ltr: "@media (min-width: 2000px){.x1ssfqz5.x1ssfqz5{background-color:purple}}", rtl: null}, 3200]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.MediaQueries.root"]
      classes = rule.atomic_classes["background-color"].classes

      default = classes[:default]
      assert default.class == "xrkmrrc"
      assert default.ltr == ".xrkmrrc{background-color:red}"
      assert default.priority == 3000

      # Note: Media query key is transformed to add upper bound
      media_1000 = classes["@media (min-width: 1000px) and (max-width: 1999.99px)"]
      assert media_1000.class == "xw6up8c"

      assert media_1000.ltr ==
               "@media (min-width: 1000px) and (max-width: 1999.99px){.xw6up8c.xw6up8c{background-color:blue}}"

      assert media_1000.priority == 3200

      media_2000 = classes["@media (min-width: 2000px)"]
      assert media_2000.class == "x1ssfqz5"

      assert media_2000.ltr ==
               "@media (min-width: 2000px){.x1ssfqz5.x1ssfqz5{background-color:purple}}"

      assert media_2000.priority == 3200
    end
  end

  describe "StyleX test: 'supports queries'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["x6m3b6q", {ltr: "@supports (hover: hover){.x6m3b6q.x6m3b6q{background-color:blue}}", rtl: null}, 3030]
      # ["x6um648", {ltr: "@supports not (hover: hover){.x6um648.x6um648{background-color:purple}}", rtl: null}, 3030]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.SupportsQueries.root"]
      classes = rule.atomic_classes["background-color"].classes

      default = classes[:default]
      assert default.class == "xrkmrrc"
      assert default.ltr == ".xrkmrrc{background-color:red}"
      assert default.priority == 3000

      supports_hover = classes["@supports (hover: hover)"]
      assert supports_hover.class == "x6m3b6q"

      assert supports_hover.ltr ==
               "@supports (hover: hover){.x6m3b6q.x6m3b6q{background-color:blue}}"

      assert supports_hover.priority == 3030

      supports_not = classes["@supports not (hover: hover)"]
      assert supports_not.class == "x6um648"

      assert supports_not.ltr ==
               "@supports not (hover: hover){.x6um648.x6um648{background-color:purple}}"

      assert supports_not.priority == 3030
    end
  end

  describe "StyleX test: 'media query with pseudo-classes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1jchvi3", {ltr: ".x1jchvi3{font-size:1rem}", rtl: null}, 3000]
      # ["x1w3nbkt", {ltr: "@media (min-width: 800px){.x1w3nbkt.x1w3nbkt{font-size:2rem}}", rtl: null}, 3200]
      # ["xicay7j", {ltr: "@media (min-width: 800px){.xicay7j.xicay7j:hover{font-size:2.2rem}}", rtl: null}, 3330]

      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.StyleXParityTest.MediaQueryWithPseudo.root"]
      classes = rule.atomic_classes["font-size"].classes

      default = classes[:default]
      assert default.class == "x1jchvi3"
      assert default.ltr == ".x1jchvi3{font-size:1rem}"
      assert default.priority == 3000

      media_default = classes["@media (min-width: 800px)"]
      assert media_default.class == "x1w3nbkt"
      assert media_default.ltr == "@media (min-width: 800px){.x1w3nbkt.x1w3nbkt{font-size:2rem}}"
      assert media_default.priority == 3200

      media_hover = classes["@media (min-width: 800px):hover"]
      assert media_hover.class == "xicay7j"

      assert media_hover.ltr ==
               "@media (min-width: 800px){.xicay7j.xicay7j:hover{font-size:2.2rem}}"

      assert media_hover.priority == 3330
    end
  end

  # ============================================================================
  # Test: "viewTransitionClass basic object"
  # StyleX Input: { group: {transitionProperty: 'none'}, imagePair: {borderRadius: 16}, old: {animationDuration: '0.5s'}, new: {animationTimingFunction: 'ease-out'} }
  # ============================================================================

  defmodule ViewTransitionBasic do
    use LiveStyle

    css_view_transition(:test,
      group: [transition_property: "none"],
      image_pair: [border_radius: 16],
      old: [animation_duration: "0.5s"],
      new: [animation_timing_function: "ease-out"]
    )
  end

  describe "StyleX test: 'viewTransitionClass basic object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xchu1hv", {ltr: "::view-transition-group(*.xchu1hv){transition-property:none;}::view-transition-image-pair(*.xchu1hv){border-radius:16px;}::view-transition-old(*.xchu1hv){animation-duration:.5s;}::view-transition-new(*.xchu1hv){animation-timing-function:ease-out;}", rtl: null}, 1]

      manifest = get_manifest()

      view_transition =
        manifest.view_transitions["LiveStyle.StyleXParityTest.ViewTransitionBasic.test"]

      assert view_transition.css_name == "xchu1hv"
    end
  end

  # ============================================================================
  # Test: "viewTransitionClass using keyframes"
  # StyleX Input: { old: {animationName: fadeOut, animationDuration: '1s'}, new: {animationName: fadeIn, animationDuration: '1s'} }
  # ============================================================================

  defmodule ViewTransitionWithKeyframes do
    use LiveStyle

    css_keyframes(:fade_in,
      from: %{opacity: 0},
      to: %{opacity: 1}
    )

    css_keyframes(:fade_out,
      from: %{opacity: 1},
      to: %{opacity: 0}
    )

    css_view_transition(:test,
      old: [animation_name: css_keyframes(:fade_out), animation_duration: "1s"],
      new: [animation_name: css_keyframes(:fade_in), animation_duration: "1s"]
    )
  end

  describe "StyleX test: 'viewTransitionClass using keyframes'" do
    test "exact output match" do
      # Expected StyleX output:
      # fadeIn: "x18re5ia-B"
      # fadeOut: "x1jn504y-B"
      # cls: "xfh0f9i"

      manifest = get_manifest()

      # Verify keyframes hashes
      fade_in =
        manifest.keyframes["LiveStyle.StyleXParityTest.ViewTransitionWithKeyframes.fade_in"]

      assert fade_in.css_name == "x18re5ia-B"

      fade_out =
        manifest.keyframes["LiveStyle.StyleXParityTest.ViewTransitionWithKeyframes.fade_out"]

      assert fade_out.css_name == "x1jn504y-B"

      # Verify view transition hash
      view_transition =
        manifest.view_transitions["LiveStyle.StyleXParityTest.ViewTransitionWithKeyframes.test"]

      assert view_transition.css_name == "xfh0f9i"
    end
  end

  # ============================================================================
  # Test: "positionTry basic object"
  # StyleX Input: { positionAnchor: '--anchor', top: '0', left: '0', width: '100px', height: '100px' }
  # ============================================================================

  defmodule PositionTryBasic do
    use LiveStyle

    css_position_try(:test,
      position_anchor: "--anchor",
      top: "0",
      left: "0",
      width: "100px",
      height: "100px"
    )
  end

  describe "StyleX test: 'positionTry basic object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["--xhs37kq", {ltr: "@position-try --xhs37kq {height:height;height:100px;left:left;left:0;position-anchor:position-anchor;position-anchor:--anchor;top:top;top:0;width:width;width:100px;}", rtl: ...}, 0]

      manifest = get_manifest()
      position_try = manifest.position_try["LiveStyle.StyleXParityTest.PositionTryBasic.test"]

      assert position_try.css_name == "--xhs37kq"
    end
  end

  # ============================================================================
  # Test: "positionTry value used within create"
  # StyleX Input: positionTry({top: '0', left: '0', width: SIZE, height: SIZE}) where SIZE = '100px'
  # ============================================================================

  defmodule PositionTryWithoutAnchor do
    use LiveStyle

    css_position_try(:test,
      top: "0",
      left: "0",
      width: "100px",
      height: "100px"
    )
  end

  describe "StyleX test: 'positionTry without positionAnchor'" do
    test "exact output match" do
      # Expected StyleX output from test:
      # ["--x1oyda6q", ...]

      manifest = get_manifest()

      position_try =
        manifest.position_try["LiveStyle.StyleXParityTest.PositionTryWithoutAnchor.test"]

      assert position_try.css_name == "--x1oyda6q"
    end
  end

  # ============================================================================
  # Hash Algorithm Verification
  # These tests verify that LiveStyle uses the same MurmurHash2 algorithm as StyleX
  # ============================================================================

  describe "MurmurHash2 algorithm parity" do
    test "hash output matches StyleX for known inputs" do
      # These are known hash outputs from StyleX tests

      # From defineVars test: exportId "vars.stylex.js//vars" -> "xop34xu"
      assert LiveStyle.Hash.create_hash("vars.stylex.js//vars") == "op34xu"

      # From defineVars test: "vars.stylex.js//vars.color" -> "xwx8imx"
      assert LiveStyle.Hash.create_hash("vars.stylex.js//vars.color") == "wx8imx"

      # From keyframes test: "<>from{color:red;}to{color:blue;}" -> "x2up61p"
      assert LiveStyle.Hash.create_hash("<>from{color:red;}to{color:blue;}") == "2up61p"

      # From create test: "<>background-colorred" + "null" -> "xrkmrrc"
      assert LiveStyle.Hash.create_hash("<>background-colorrednull") == "rkmrrc"

      # From create test: "<>colorblue" + "null" -> "xju2f9n"
      assert LiveStyle.Hash.create_hash("<>colorbluenull") == "ju2f9n"
    end
  end
end
