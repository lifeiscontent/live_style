defmodule LiveStyle.StyleXParityTest do
  @moduledoc """
  Comprehensive StyleX parity tests.

  This file mirrors StyleX's transform-stylex-create-test.js to ensure
  LiveStyle produces EXACTLY the same output as StyleX for each test case.

  Each test includes:
  - The original StyleX test name
  - The StyleX input
  - The expected CSS output (class name, ltr)

  Format: .class{property:value}
  """
  use LiveStyle.TestCase

  # ============================================================================
  # Test: "style object"
  # StyleX Input: { backgroundColor: 'red', color: 'blue' }
  # ============================================================================

  defmodule StyleObject do
    use LiveStyle

    class(:root,
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

    class(:root, background_color: "red")
    class(:other, color: "blue")
    class(:bar_baz, color: "green")
    class(:purple_color, color: "purple")
  end

  # ============================================================================
  # Test: "style object with custom properties"
  # StyleX Input: { '--background-color': 'red', '--otherColor': 'green', '--foo': 10 }
  # ============================================================================

  defmodule CustomProperties do
    use LiveStyle

    class(:root,
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

    class(:root, user_select: "none")
  end

  # ============================================================================
  # Test: "use array (fallbacks)"
  # StyleX Input: { position: ['sticky', 'fixed'] }
  # ============================================================================

  defmodule ArrayFallbacks do
    use LiveStyle

    class(:root, position: ["sticky", "fixed"])
  end

  # ============================================================================
  # Test: "valid pseudo-class"
  # StyleX Input: { backgroundColor: { ':hover': 'red' }, color: { ':hover': 'blue' } }
  # ============================================================================

  defmodule ValidPseudoClass do
    use LiveStyle

    class(:root,
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

    class(:root,
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
    class(:root,
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

    class(:foo,
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

    class(:foo,
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

    keyframes(:name,
      from: [color: "red"],
      to: [color: "blue"]
    )
  end

  # ============================================================================
  # Test: "media queries"
  # StyleX Input: { backgroundColor: { default: 'red', '@media ...': 'blue', '@media ...': 'purple' } }
  # ============================================================================

  defmodule MediaQueries do
    use LiveStyle

    class(:root,
      background_color: [
        default: "red",
        "@media (min-width: 1000px)": "blue",
        "@media (min-width: 2000px)": "purple"
      ]
    )
  end

  # ============================================================================
  # Test: "supports queries"
  # StyleX Input: { backgroundColor: { default: 'red', '@supports ...': 'blue', '@supports not ...': 'purple' } }
  # ============================================================================

  defmodule SupportsQueries do
    use LiveStyle

    class(:root,
      background_color: [
        default: "red",
        "@supports (hover: hover)": "blue",
        "@supports not (hover: hover)": "purple"
      ]
    )
  end

  # ============================================================================
  # Test: "media query with pseudo-classes"
  # StyleX Input: { fontSize: { default: '1rem', '@media ...': { default: '2rem', ':hover': '2.2rem' } } }
  # ============================================================================

  defmodule MediaQueryWithPseudo do
    use LiveStyle

    class(:root,
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
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xrkmrrc{background-color:red}"
      assert css =~ ".xju2f9n{color:blue}"
    end
  end

  describe "StyleX test: 'style object (multiple)'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xju2f9n", {ltr: ".xju2f9n{color:blue}", rtl: null}, 3000]
      # ["x1prwzq3", {ltr: ".x1prwzq3{color:green}", rtl: null}, 3000]
      # ["x125ip1n", {ltr: ".x125ip1n{color:purple}", rtl: null}, 3000]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xrkmrrc{background-color:red}"
      assert css =~ ".xju2f9n{color:blue}"
      assert css =~ ".x1prwzq3{color:green}"
      assert css =~ ".x125ip1n{color:purple}"
    end
  end

  describe "StyleX test: 'style object with custom properties'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xgau0yw", {ltr: ".xgau0yw{--background-color:red}", rtl: null}, 1]
      # ["x1p9b6ba", {ltr: ".x1p9b6ba{--otherColor:green}", rtl: null}, 1]
      # ["x40g909", {ltr: ".x40g909{--foo:10}", rtl: null}, 1]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xgau0yw{--background-color:red}"
      assert css =~ ".x1p9b6ba{--otherColor:green}"
      assert css =~ ".x40g909{--foo:10}"
    end
  end

  describe "StyleX test: 'style object requiring vendor prefixes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x87ps6o", {ltr: ".x87ps6o{user-select:none}", rtl: null}, 3000]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x87ps6o{user-select:none}"
    end
  end

  describe "StyleX test: 'use array (fallbacks)'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1ruww2u", {ltr: ".x1ruww2u{position:sticky;position:fixed}", rtl: null}, 3000]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1ruww2u{position:sticky;position:fixed}"
    end
  end

  describe "StyleX test: 'valid pseudo-class'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1gykpug", {ltr: ".x1gykpug:not(#\\#):hover{background-color:red}", rtl: null}, 3130]
      # ["x17z2mba", {ltr: ".x17z2mba:not(#\\#):hover{color:blue}", rtl: null}, 3130]
      # Note: LiveStyle uses :not(#\#) for specificity
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1gykpug:not(#\\#):hover{background-color:red}"
      assert css =~ ".x17z2mba:not(#\\#):hover{color:blue}"
    end
  end

  describe "StyleX test: 'pseudo-class generated order'" do
    test "exact output match" do
      # Expected StyleX output (with :not(#\#) specificity hack):
      # ["x17z2mba", {ltr: ".x17z2mba:not(#\\#):hover{color:blue}", rtl: null}, 3130]
      # ["x96fq8s", {ltr: ".x96fq8s:not(#\\#):active{color:red}", rtl: null}, 3170]
      # ["x1wvtd7d", {ltr: ".x1wvtd7d:not(#\\#):focus{color:yellow}", rtl: null}, 3150]
      # ["x126ychx", {ltr: ".x126ychx:not(#\\#):nth-child(2n){color:purple}", rtl: null}, 3060]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x17z2mba:not(#\\#):hover{color:blue}"
      assert css =~ ".x96fq8s:not(#\\#):active{color:red}"
      assert css =~ ".x1wvtd7d:not(#\\#):focus{color:yellow}"
      assert css =~ ".x126ychx:not(#\\#):nth-child(2n){color:purple}"
    end
  end

  describe "StyleX test: 'pseudo-class generated order (nested, same value)'" do
    test "exact output match" do
      # StyleX metadata output: .xa2ikkt:active:hover{color:red}
      # StyleX sorts pseudo-classes alphabetically, so :active comes before :hover
      # We add :not(#\#) for specificity (StyleX does this during CSS injection)
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xa2ikkt:not(#\\#):active:hover{color:red}"
    end
  end

  describe ~s(StyleX test: "::before" and "::after") do
    test "exact output match" do
      # Expected StyleX output:
      # ["x16oeupf", {ltr: ".x16oeupf::before{color:red}", rtl: null}, 8000]
      # ["xdaarc3", {ltr: ".xdaarc3::after{color:blue}", rtl: null}, 8000]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x16oeupf::before{color:red}"
      assert css =~ ".xdaarc3::after{color:blue}"
    end
  end

  describe "StyleX test: '\"::before\" containing pseudo-classes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x16oeupf", {ltr: ".x16oeupf::before{color:red}", rtl: null}, 8000]
      # ["xeb2lg0", {ltr: ".xeb2lg0::before:hover{color:blue}", rtl: null}, 8130]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x16oeupf::before{color:red}"
      assert css =~ ".xeb2lg0::before:hover{color:blue}"
    end
  end

  describe "StyleX test: 'keyframes object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x2up61p-B", {ltr: "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}", rtl: null}, 0]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
    end
  end

  describe "StyleX test: 'media queries'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xw6up8c", {ltr: "@media ...{.xw6up8c:not(#\\#){background-color:blue}}", rtl: null}, 3200]
      # ["x1ssfqz5", {ltr: "@media (min-width: 2000px){.x1ssfqz5:not(#\\#){background-color:purple}}", rtl: null}, 3200]
      css = LiveStyle.Compiler.generate_css()

      # Default value
      assert css =~ ".xrkmrrc{background-color:red}"

      # Media query with bounded range (transformed)
      # Note: LiveStyle uses :not(#\#) for specificity instead of double class
      assert css =~
               "@media (min-width: 1000px) and (max-width: 1999.99px){.xw6up8c:not(#\\#){background-color:blue}}"

      # Final media query (no upper bound)
      assert css =~ "@media (min-width: 2000px){.x1ssfqz5:not(#\\#){background-color:purple}}"
    end
  end

  describe "StyleX test: 'supports queries'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["x6m3b6q", {ltr: "@supports (hover: hover){.x6m3b6q:not(#\\#){background-color:blue}}", rtl: null}, 3030]
      # ["x6um648", {ltr: "@supports not (hover: hover){.x6um648:not(#\\#){background-color:purple}}", rtl: null}, 3030]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".xrkmrrc{background-color:red}"
      assert css =~ "@supports (hover: hover){.x6m3b6q:not(#\\#){background-color:blue}}"
      assert css =~ "@supports not (hover: hover){.x6um648:not(#\\#){background-color:purple}}"
    end
  end

  describe "StyleX test: 'media query with pseudo-classes'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["x1jchvi3", {ltr: ".x1jchvi3{font-size:1rem}", rtl: null}, 3000]
      # ["x1w3nbkt", {ltr: "@media (min-width: 800px){.x1w3nbkt:not(#\\#){font-size:2rem}}", rtl: null}, 3200]
      # ["xicay7j", {ltr: "@media (min-width: 800px){.xicay7j:not(#\\#):hover{font-size:2.2rem}}", rtl: null}, 3330]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ".x1jchvi3{font-size:1rem}"
      assert css =~ "@media (min-width: 800px){.x1w3nbkt:not(#\\#){font-size:2rem}}"
      assert css =~ "@media (min-width: 800px){.xicay7j:not(#\\#):hover{font-size:2.2rem}}"
    end
  end

  # ============================================================================
  # Test: "viewTransitionClass basic object"
  # StyleX Input: { group: {transitionProperty: 'none'}, imagePair: {borderRadius: 16}, ... }
  # ============================================================================

  defmodule ViewTransitionBasic do
    use LiveStyle

    view_transition_class(:test,
      group: [transition_property: "none"],
      image_pair: [border_radius: 16],
      old: [animation_duration: "0.5s"],
      new: [animation_timing_function: "ease-out"]
    )
  end

  describe "StyleX test: 'viewTransitionClass basic object'" do
    test "exact output match" do
      # Expected StyleX output:
      # ["xchu1hv", {ltr: "::view-transition-group(*.xchu1hv){...}...", rtl: null}, 1]
      css = LiveStyle.Compiler.generate_css()

      # View transition class should generate CSS with view-transition pseudo-elements
      assert css =~ "::view-transition-group(*.xchu1hv){transition-property:none;}"
      assert css =~ "::view-transition-image-pair(*.xchu1hv){border-radius:16px;}"
      assert css =~ "::view-transition-old(*.xchu1hv){animation-duration:.5s;}"
      assert css =~ "::view-transition-new(*.xchu1hv){animation-timing-function:ease-out;}"
    end
  end

  # ============================================================================
  # Test: "viewTransitionClass using keyframes"
  # StyleX Input: { old: {animationName: fadeOut, ...}, new: {animationName: fadeIn, ...} }
  # ============================================================================

  defmodule ViewTransitionWithKeyframes do
    use LiveStyle

    keyframes(:fade_in,
      from: [opacity: 0],
      to: [opacity: 1]
    )

    keyframes(:fade_out,
      from: [opacity: 1],
      to: [opacity: 0]
    )

    view_transition_class(:test,
      old: [animation_name: keyframes(:fade_out), animation_duration: "1s"],
      new: [animation_name: keyframes(:fade_in), animation_duration: "1s"]
    )
  end

  describe "StyleX test: 'viewTransitionClass using keyframes'" do
    test "exact output match" do
      # Expected StyleX output:
      # fadeIn: "x18re5ia-B"
      # fadeOut: "x1jn504y-B"
      # cls: "xfh0f9i"
      css = LiveStyle.Compiler.generate_css()

      # Keyframes should exist
      assert css =~ "@keyframes x18re5ia-B{from{opacity:0;}to{opacity:1;}}"
      assert css =~ "@keyframes x1jn504y-B{from{opacity:1;}to{opacity:0;}}"

      # View transition should reference keyframes (preserving insertion order like StyleX)
      assert css =~
               "::view-transition-old(*.xfh0f9i){animation-name:x1jn504y-B;animation-duration:1s;}"

      assert css =~
               "::view-transition-new(*.xfh0f9i){animation-name:x18re5ia-B;animation-duration:1s;}"
    end
  end

  # ============================================================================
  # Test: "positionTry basic object"
  # StyleX Input: { positionAnchor: '--anchor', top: '0', left: '0', width: '100px', height: '100px' }
  # ============================================================================

  defmodule PositionTryBasic do
    use LiveStyle

    position_try(:test,
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
      # ["--xhs37kq", {ltr: "@position-try --xhs37kq {...}", rtl: ...}, 0]
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "@position-try --xhs37kq"
      assert css =~ "position-anchor:--anchor"
      assert css =~ "width:100px"
      assert css =~ "height:100px"
    end
  end

  # ============================================================================
  # Test: "positionTry value used within create"
  # StyleX Input: positionTry({top: '0', left: '0', width: SIZE, height: SIZE}) where SIZE = '100px'
  # ============================================================================

  defmodule PositionTryWithoutAnchor do
    use LiveStyle

    position_try(:test,
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
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "@position-try --x1oyda6q"
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
