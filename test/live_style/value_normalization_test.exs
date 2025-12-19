defmodule LiveStyle.ValueNormalizationTest do
  @moduledoc """
  Tests for CSS value normalization.

  These tests mirror StyleX's transform-value-normalization-test.js to ensure
  LiveStyle normalizes values the same way StyleX does.
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Whitespace Normalization
  # ============================================================================

  defmodule WhitespaceNormalization do
    use LiveStyle

    css_class(:transform_spaces, transform: "  rotate(10deg)  translate3d( 0 , 0 , 0 )  ")
    css_class(:rgba_spaces, color: "rgba( 1, 222,  33 , 0.5)")
  end

  # ============================================================================
  # Zero Values
  # ============================================================================

  defmodule ZeroValues do
    use LiveStyle

    css_class(:zero_px, margin: "0px", margin_left: "1px")
    css_class(:zero_timing, transition_duration: "0ms")
    css_class(:zero_angle_rad, transform: "0rad")
    css_class(:zero_angle_turn, transform: "0turn")
    css_class(:zero_angle_grad, transform: "0grad")
    # Integer 0 should normalize to "0" (not "0px")
    # StyleX: margin: 0 -> ".x1ghz6dp{margin:0}"
    css_class(:zero_integer, margin: 0, padding: 0)
  end

  # ============================================================================
  # Calc Values
  # ============================================================================

  defmodule CalcValues do
    use LiveStyle

    css_class(:calc_spaces, width: "calc((100% + 3% -   100px) / 7)")
    # Nested calc functions
    css_class(:nested_calc, width: "calc(100% - calc(20px + 10px))")
    css_class(:deeply_nested_calc, height: "calc(50vh - calc(100% / calc(3 + 1)))")
    # Nested functions in clamp
    css_class(:clamp_with_calc, padding: "clamp(10px, calc(1rem + 2vw), 30px)")
  end

  # ============================================================================
  # Leading Zeros
  # ============================================================================

  defmodule LeadingZeros do
    use LiveStyle

    css_class(:decimal, transition_duration: "0.01s")
    css_class(:cubic_bezier, transition_timing_function: "cubic-bezier(.08,.52,.52,1)")
  end

  # ============================================================================
  # Timing Values
  # ============================================================================

  defmodule TimingValues do
    use LiveStyle

    css_class(:ms_large, transition_duration: "1234ms")
    css_class(:ms_medium, transition_duration: "10ms")
    css_class(:ms_small, transition_duration: "1ms")
    css_class(:ms_500, transition_duration: "500ms")
  end

  # ============================================================================
  # Unitless vs Unit-Requiring Values
  # ============================================================================

  defmodule UnitlessValues do
    use LiveStyle

    # These properties need px units added
    css_class(:with_units,
      height: 500,
      margin: 10,
      width: 500
    )

    # These properties are unitless
    css_class(:unitless,
      font_weight: 500,
      line_height: 1.5,
      opacity: 0.5,
      zoom: 2
    )
  end

  # ============================================================================
  # Number Rounding
  # ============================================================================

  defmodule NumberRounding do
    use LiveStyle

    # 100/3 = 33.333333... should round to 33.3333
    css_class(:rounded, height: 33.33333333)
  end

  # ============================================================================
  # Content Property
  # ============================================================================

  defmodule ContentProperty do
    use LiveStyle

    css_class(:empty, content: "")
    css_class(:with_text, content: "hello")
    css_class(:with_attr, content: "attr(data-count)")
    css_class(:open_quote, content: "open-quote")
    css_class(:close_quote, content: "close-quote")
    css_class(:no_open_quote, content: "no-open-quote")
    css_class(:no_close_quote, content: "no-close-quote")
    css_class(:counter_fn, content: "counter(section)")
    css_class(:counters_fn, content: "counters(section, '.')")
    css_class(:var_fn, content: "var(--my-content)")
  end

  # ============================================================================
  # Hyphenate-Character Property
  # ============================================================================

  defmodule HyphenateCharacter do
    use LiveStyle

    css_class(:auto, hyphenate_character: "auto")
    css_class(:dash, hyphenate_character: "-")
    css_class(:custom, hyphenate_character: "=")
  end

  # ============================================================================
  # Quotes Property (Empty String Normalization)
  # ============================================================================

  defmodule QuotesProperty do
    use LiveStyle

    # StyleX: quotes: "''" -> ".x169joja{quotes:\"\"}"
    # Single-quoted empty strings are normalized to double-quoted
    css_class(:empty_single, quotes: "''")
    css_class(:empty_double, quotes: "\"\"")
  end

  # ============================================================================
  # Transition-Property Value Conversion
  # ============================================================================

  defmodule TransitionPropertyValues do
    use LiveStyle

    # Atom values (snake_case -> dash-case)
    css_class(:atom_single, transition_property: :background_color)
    css_class(:atom_opacity, transition_property: :opacity)

    # String values (snake_case -> dash-case for Elixir idiom)
    css_class(:string_snake, transition_property: "background_color")
    css_class(:string_multi, transition_property: "opacity, background_color, border_radius")
    css_class(:string_custom_prop, transition_property: "--my_custom_prop")
  end

  # ============================================================================
  # !important Handling
  # ============================================================================

  defmodule ImportantValues do
    use LiveStyle

    # StyleX removes space before !important: "red !important" -> "red!important"
    css_class(:important, color: "red !important")
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "whitespace normalization" do
    test "normalizes whitespace in transform values" do
      # StyleX: ".x18qx21s{transform:rotate(10deg) translate3d(0,0,0)}"
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.ValueNormalizationTest.WhitespaceNormalization.transform_spaces"
        ]

      meta = rule.atomic_classes["transform"]
      assert meta.class == "x18qx21s"
      assert meta.ltr == ".x18qx21s{transform:rotate(10deg) translate3d(0,0,0)}"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end

    test "normalizes whitespace in rgba values" do
      # StyleX: ".xe1l9yr{color:rgba(1,222,33,.5)}"
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.ValueNormalizationTest.WhitespaceNormalization.rgba_spaces"]

      meta = rule.atomic_classes["color"]
      assert meta.class == "xe1l9yr"
      assert meta.ltr == ".xe1l9yr{color:rgba(1,222,33,.5)}"
      assert meta.rtl == nil
      assert meta.priority == 3000
    end
  end

  describe "zero values" do
    test "removes units from 0 length values" do
      # StyleX: ".x1ghz6dp{margin:0}" and ".xgsvwom{margin-left:1px}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_px"]

      # margin: 0 (units removed)
      margin_meta = rule.atomic_classes["margin"]
      assert margin_meta.class == "x1ghz6dp"
      assert margin_meta.ltr == ".x1ghz6dp{margin:0}"
      assert margin_meta.priority == 1000

      # margin-left: 1px (units preserved for non-zero)
      margin_left_meta = rule.atomic_classes["margin-left"]
      assert margin_left_meta.class == "xgsvwom"
      assert margin_left_meta.ltr == ".xgsvwom{margin-left:1px}"
      assert margin_left_meta.priority == 4000
    end

    test "converts 0ms timing to 0s" do
      # StyleX: ".x1mq3mr6{transition-duration:0s}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_timing"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "x1mq3mr6"
      assert meta.ltr == ".x1mq3mr6{transition-duration:0s}"
      assert meta.priority == 3000
    end

    test "converts 0rad to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_angle_rad"]

      meta = rule.atomic_classes["transform"]
      assert meta.class == "x1jpfit1"
      assert meta.ltr == ".x1jpfit1{transform:0deg}"
      assert meta.priority == 3000
    end

    test "converts 0turn to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_angle_turn"]

      meta = rule.atomic_classes["transform"]
      assert meta.class == "x1jpfit1"
      assert meta.ltr == ".x1jpfit1{transform:0deg}"
      assert meta.priority == 3000
    end

    test "converts 0grad to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_angle_grad"]

      meta = rule.atomic_classes["transform"]
      assert meta.class == "x1jpfit1"
      assert meta.ltr == ".x1jpfit1{transform:0deg}"
      assert meta.priority == 3000
    end

    test "integer 0 normalizes to 0 without unit suffix" do
      # StyleX: margin: 0 -> ".x1ghz6dp{margin:0}" (not "0px")
      # This ensures numeric 0 values don't get px suffix before normalization
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ZeroValues.zero_integer"]

      # margin: 0 -> "0" (not "0px")
      margin_meta = rule.atomic_classes["margin"]
      assert margin_meta.class == "x1ghz6dp"
      assert margin_meta.ltr == ".x1ghz6dp{margin:0}"
      assert margin_meta.priority == 1000

      # padding: 0 -> "0" (not "0px")
      padding_meta = rule.atomic_classes["padding"]
      assert padding_meta.class == "x1717udv"
      assert padding_meta.ltr == ".x1717udv{padding:0}"
      assert padding_meta.priority == 1000
    end
  end

  describe "calc() values" do
    test "preserves spaces around + and - in calc()" do
      # StyleX: ".x1hauit9{width:calc((100% + 3% - 100px) / 7)}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.CalcValues.calc_spaces"]

      meta = rule.atomic_classes["width"]
      assert meta.class == "x1hauit9"
      assert meta.ltr == ".x1hauit9{width:calc((100% + 3% - 100px) / 7)}"
      assert meta.priority == 4000
    end

    test "nested calc() functions are preserved" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.CalcValues.nested_calc"]

      meta = rule.atomic_classes["width"]
      assert meta.ltr =~ "calc(100% - calc(20px + 10px))"
    end

    test "deeply nested calc() functions are preserved" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.CalcValues.deeply_nested_calc"]

      meta = rule.atomic_classes["height"]
      assert meta.ltr =~ "calc(50vh - calc(100% / calc(3 + 1)))"
    end

    test "calc() inside clamp() is preserved" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.CalcValues.clamp_with_calc"]

      meta = rule.atomic_classes["padding"]
      assert meta.ltr =~ "clamp(10px,calc(1rem + 2vw),30px)"
    end
  end

  describe "leading zeros" do
    test "strips leading zeros from decimal values" do
      # StyleX: ".xpvlhck{transition-duration:.01s}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.LeadingZeros.decimal"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "xpvlhck"
      assert meta.ltr == ".xpvlhck{transition-duration:.01s}"
      assert meta.priority == 3000
    end

    test "cubic-bezier values strip leading zeros" do
      # StyleX: ".xxziih7{transition-timing-function:cubic-bezier(.08,.52,.52,1)}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.LeadingZeros.cubic_bezier"]

      meta = rule.atomic_classes["transition-timing-function"]
      assert meta.class == "xxziih7"
      assert meta.ltr == ".xxziih7{transition-timing-function:cubic-bezier(.08,.52,.52,1)}"
      assert meta.priority == 3000
    end
  end

  describe "timing values" do
    test "converts 1234ms to 1.234s" do
      # StyleX: ".xsa3hc2{transition-duration:1.234s}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.TimingValues.ms_large"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "xsa3hc2"
      assert meta.ltr == ".xsa3hc2{transition-duration:1.234s}"
      assert meta.priority == 3000
    end

    test "converts 10ms to .01s" do
      # StyleX: ".xpvlhck{transition-duration:.01s}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.TimingValues.ms_medium"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "xpvlhck"
      assert meta.ltr == ".xpvlhck{transition-duration:.01s}"
      assert meta.priority == 3000
    end

    test "keeps 1ms as is (below 10ms threshold)" do
      # StyleX: ".xjd9b36{transition-duration:1ms}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.TimingValues.ms_small"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "xjd9b36"
      assert meta.ltr == ".xjd9b36{transition-duration:1ms}"
      assert meta.priority == 3000
    end

    test "converts 500ms to .5s" do
      # StyleX: ".x1wsgiic{transition-duration:.5s}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.TimingValues.ms_500"]

      meta = rule.atomic_classes["transition-duration"]
      assert meta.class == "x1wsgiic"
      assert meta.ltr == ".x1wsgiic{transition-duration:.5s}"
      assert meta.priority == 3000
    end
  end

  describe "unitless vs unit-requiring properties" do
    test "adds px to height numeric value" do
      # StyleX: ".x1egiwwb{height:500px}" with priority 4000
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.with_units"]

      meta = rule.atomic_classes["height"]
      assert meta.class == "x1egiwwb"
      assert meta.ltr == ".x1egiwwb{height:500px}"
      assert meta.priority == 4000
    end

    test "adds px to margin numeric value" do
      # StyleX: ".x1oin6zd{margin:10px}" with priority 1000
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.with_units"]

      meta = rule.atomic_classes["margin"]
      assert meta.class == "x1oin6zd"
      assert meta.ltr == ".x1oin6zd{margin:10px}"
      assert meta.priority == 1000
    end

    test "adds px to width numeric value" do
      # StyleX: ".xvue9z{width:500px}" with priority 4000
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.with_units"]

      meta = rule.atomic_classes["width"]
      assert meta.class == "xvue9z"
      assert meta.ltr == ".xvue9z{width:500px}"
      assert meta.priority == 4000
    end

    test "does not add units to font-weight" do
      # StyleX: ".xk50ysn{font-weight:500}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.unitless"]

      meta = rule.atomic_classes["font-weight"]
      assert meta.class == "xk50ysn"
      assert meta.ltr == ".xk50ysn{font-weight:500}"
      assert meta.priority == 3000
    end

    test "does not add units to line-height" do
      # StyleX: ".x1evy7pa{line-height:1.5}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.unitless"]

      meta = rule.atomic_classes["line-height"]
      assert meta.class == "x1evy7pa"
      assert meta.ltr == ".x1evy7pa{line-height:1.5}"
      assert meta.priority == 3000
    end

    test "strips leading zero from opacity and does not add units" do
      # StyleX: ".xbyyjgo{opacity:.5}"
      # Note: StyleX produces xbyyjgo but we might have different hash
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.unitless"]

      meta = rule.atomic_classes["opacity"]
      # Opacity 0.5 should become .5 (leading zero stripped)
      assert meta.ltr =~ ~r/opacity:\.5\}/
      assert meta.priority == 3000
    end

    test "does not add units to zoom" do
      # StyleX: ".xy2o3ld{zoom:2}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.UnitlessValues.unitless"]

      meta = rule.atomic_classes["zoom"]
      assert meta.class == "xy2o3ld"
      assert meta.ltr == ".xy2o3ld{zoom:2}"
      assert meta.priority == 3000
    end
  end

  describe "number rounding" do
    test "rounds numbers to 4 decimal places" do
      # StyleX: ".x1vvwc6p{height:33.3333px}" with priority 4000
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.NumberRounding.rounded"]

      meta = rule.atomic_classes["height"]
      assert meta.class == "x1vvwc6p"
      assert meta.ltr == ".x1vvwc6p{height:33.3333px}"
      assert meta.priority == 4000
    end
  end

  describe "content property" do
    test "wraps empty content in quotes" do
      # StyleX: ".x14axycx{content:\"\"}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.empty"]

      meta = rule.atomic_classes["content"]
      assert meta.class == "x14axycx"
      assert meta.ltr == ".x14axycx{content:\"\"}"
      assert meta.priority == 3000
    end

    test "wraps text content in quotes" do
      # StyleX: ".x1r2f195{content:\"hello\"}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.with_text"]

      meta = rule.atomic_classes["content"]
      assert meta.class == "x1r2f195"
      assert meta.ltr == ".x1r2f195{content:\"hello\"}"
      assert meta.priority == 3000
    end

    test "does not wrap attr() function in quotes" do
      # StyleX does not wrap special functions like attr()
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.with_attr"]

      meta = rule.atomic_classes["content"]
      assert meta.class == "xli7a2p"
      assert meta.ltr == ".xli7a2p{content:attr(data-count)}"
      assert meta.priority == 3000
    end

    test "does not wrap open-quote keyword in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.open_quote"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:open-quote\}/
    end

    test "does not wrap close-quote keyword in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.close_quote"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:close-quote\}/
    end

    test "does not wrap no-open-quote keyword in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.no_open_quote"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:no-open-quote\}/
    end

    test "does not wrap no-close-quote keyword in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.no_close_quote"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:no-close-quote\}/
    end

    test "does not wrap counter() function in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.counter_fn"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:counter\(section\)\}/
    end

    test "does not wrap counters() function in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.counters_fn"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:counters\(section/
    end

    test "does not wrap var() function in quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ContentProperty.var_fn"]

      meta = rule.atomic_classes["content"]
      assert meta.ltr =~ ~r/content:var\(--my-content\)\}/
    end
  end

  describe "hyphenate-character property" do
    test "auto keyword is not quoted" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.HyphenateCharacter.auto"]

      meta = rule.atomic_classes["hyphenate-character"]
      assert meta.ltr =~ ~r/hyphenate-character:auto\}/
    end

    test "dash character is quoted" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.HyphenateCharacter.dash"]

      meta = rule.atomic_classes["hyphenate-character"]
      assert meta.ltr =~ ~r/hyphenate-character:"-"\}/
    end

    test "custom character is quoted" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.HyphenateCharacter.custom"]

      meta = rule.atomic_classes["hyphenate-character"]
      assert meta.ltr =~ ~r/hyphenate-character:"="\}/
    end
  end

  describe "quotes property normalization" do
    test "single-quoted empty string normalizes to double quotes" do
      # StyleX: quotes: "''" -> ".x169joja{quotes:\"\"}"
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.QuotesProperty.empty_single"]

      meta = rule.atomic_classes["quotes"]
      assert meta.class == "x169joja"
      assert meta.ltr == ".x169joja{quotes:\"\"}"
      assert meta.priority == 3000
    end

    test "double-quoted empty string stays as double quotes" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.QuotesProperty.empty_double"]

      meta = rule.atomic_classes["quotes"]
      assert meta.class == "x169joja"
      assert meta.ltr == ".x169joja{quotes:\"\"}"
      assert meta.priority == 3000
    end
  end

  describe "transition-property value conversion" do
    test "converts atom snake_case to dash-case" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.ValueNormalizationTest.TransitionPropertyValues.atom_single"]

      meta = rule.atomic_classes["transition-property"]
      assert meta.ltr =~ ~r/transition-property:background-color\}/
    end

    test "preserves simple atom values" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.ValueNormalizationTest.TransitionPropertyValues.atom_opacity"]

      meta = rule.atomic_classes["transition-property"]
      assert meta.ltr =~ ~r/transition-property:opacity\}/
    end

    test "converts string snake_case to dash-case" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.ValueNormalizationTest.TransitionPropertyValues.string_snake"]

      meta = rule.atomic_classes["transition-property"]
      assert meta.ltr =~ ~r/transition-property:background-color\}/
    end

    test "converts multiple comma-separated snake_case values" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.ValueNormalizationTest.TransitionPropertyValues.string_multi"]

      meta = rule.atomic_classes["transition-property"]
      # Should be "opacity,background-color,border-radius"
      assert meta.ltr =~ ~r/transition-property:opacity,background-color,border-radius\}/
    end

    test "preserves custom properties (does not convert underscores)" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.ValueNormalizationTest.TransitionPropertyValues.string_custom_prop"
        ]

      meta = rule.atomic_classes["transition-property"]
      # Custom props starting with -- should preserve underscores
      assert meta.ltr =~ ~r/transition-property:--my_custom_prop\}/
    end
  end

  describe "!important handling" do
    test "removes space before !important" do
      # StyleX: ".xzw3067{color:red!important}"
      # No space before !important
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.ValueNormalizationTest.ImportantValues.important"]

      meta = rule.atomic_classes["color"]
      assert meta.class == "xzw3067"
      assert meta.ltr == ".xzw3067{color:red!important}"
      assert meta.priority == 3000
    end
  end
end
