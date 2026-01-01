defmodule LiveStyle.ValueNormalizationTest do
  @moduledoc """
  Tests for CSS value normalization.

  These tests mirror StyleX's transform-value-normalization-test.js to ensure
  LiveStyle normalizes values the same way StyleX does.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Compiler.Class

  # ============================================================================
  # Whitespace Normalization
  # ============================================================================

  defmodule WhitespaceNormalization do
    use LiveStyle

    class(:transform_spaces, transform: "  rotate(10deg)  translate3d( 0 , 0 , 0 )  ")
    class(:rgba_spaces, color: "rgba( 1, 222,  33 , 0.5)")
  end

  # ============================================================================
  # Zero Values
  # ============================================================================

  defmodule ZeroValues do
    use LiveStyle

    class(:zero_px, margin: "0px", margin_left: "1px")
    class(:zero_timing, transition_duration: "0ms")
    class(:zero_angle_rad, transform: "0rad")
    class(:zero_angle_turn, transform: "0turn")
    class(:zero_angle_grad, transform: "0grad")
    # Integer 0 should normalize to "0" (not "0px")
    # StyleX: margin: 0 -> ".x1ghz6dp{margin:0}"
    class(:zero_integer, margin: 0, padding: 0)
  end

  # ============================================================================
  # Calc Values
  # ============================================================================

  defmodule CalcValues do
    use LiveStyle

    class(:calc_spaces, width: "calc((100% + 3% -   100px) / 7)")
    # Nested calc functions
    class(:nested_calc, width: "calc(100% - calc(20px + 10px))")
    class(:deeply_nested_calc, height: "calc(50vh - calc(100% / calc(3 + 1)))")
    # Nested functions in clamp
    class(:clamp_with_calc, padding: "clamp(10px, calc(1rem + 2vw), 30px)")
  end

  # ============================================================================
  # Leading Zeros
  # ============================================================================

  defmodule LeadingZeros do
    use LiveStyle

    class(:decimal, transition_duration: "0.01s")
    class(:cubic_bezier, transition_timing_function: "cubic-bezier(.08,.52,.52,1)")
  end

  # ============================================================================
  # Timing Values
  # ============================================================================

  defmodule TimingValues do
    use LiveStyle

    class(:ms_large, transition_duration: "1234ms")
    class(:ms_medium, transition_duration: "10ms")
    class(:ms_small, transition_duration: "1ms")
    class(:ms_500, transition_duration: "500ms")
  end

  # ============================================================================
  # Unitless vs Unit-Requiring Values
  # ============================================================================

  defmodule UnitlessValues do
    use LiveStyle

    # These properties need px units added
    class(:with_units,
      height: 500,
      margin: 10,
      width: 500
    )

    # These properties are unitless
    class(:unitless,
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
    class(:rounded, height: 33.33333333)
  end

  # ============================================================================
  # Content Property
  # ============================================================================

  defmodule ContentProperty do
    use LiveStyle

    class(:empty, content: "")
    class(:with_text, content: "hello")
    class(:with_attr, content: "attr(data-count)")
    class(:open_quote, content: "open-quote")
    class(:close_quote, content: "close-quote")
    class(:no_open_quote, content: "no-open-quote")
    class(:no_close_quote, content: "no-close-quote")
    class(:counter_fn, content: "counter(section)")
    class(:counters_fn, content: "counters(section, '.')")
    class(:var_fn, content: "var(--my-content)")
  end

  # ============================================================================
  # Hyphenate-Character Property
  # ============================================================================

  defmodule HyphenateCharacter do
    use LiveStyle

    class(:auto, hyphenate_character: "auto")
    class(:dash, hyphenate_character: "-")
    class(:custom, hyphenate_character: "=")
  end

  # ============================================================================
  # Quotes Property (Empty String Normalization)
  # ============================================================================

  defmodule QuotesProperty do
    use LiveStyle

    # StyleX: quotes: "''" -> ".x169joja{quotes:\"\"}"
    # Single-quoted empty strings are normalized to double-quoted
    class(:empty_single, quotes: "''")
    class(:empty_double, quotes: "\"\"")
  end

  # ============================================================================
  # Transition-Property Value Conversion
  # ============================================================================

  defmodule TransitionPropertyValues do
    use LiveStyle

    # Atom values (snake_case -> dash-case)
    class(:atom_single, transition_property: :background_color)
    class(:atom_opacity, transition_property: :opacity)

    # String values (snake_case -> dash-case for Elixir idiom)
    class(:string_snake, transition_property: "background_color")
    class(:string_multi, transition_property: "opacity, background_color, border_radius")
    class(:string_custom_prop, transition_property: "--my_custom_prop")
  end

  # ============================================================================
  # !important Handling
  # ============================================================================

  defmodule ImportantValues do
    use LiveStyle

    # StyleX removes space before !important: "red !important" -> "red!important"
    class(:important, color: "red !important")
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "whitespace normalization" do
    test "normalizes whitespace in transform values" do
      # StyleX: ".x18qx21s{transform:rotate(10deg) translate3d(0,0,0)}"
      rule =
        Class.lookup!(
          {LiveStyle.ValueNormalizationTest.WhitespaceNormalization, :transform_spaces}
        )

      meta = get_atomic(rule.atomic_classes, "transform")
      assert field(meta, :class) == "x18qx21s"
      assert field(meta, :ltr) == ".x18qx21s{transform:rotate(10deg) translate3d(0,0,0)}"
      assert field(meta, :rtl) == nil
      assert field(meta, :priority) == 3000
    end

    test "normalizes whitespace in rgba values" do
      # StyleX: ".xe1l9yr{color:rgba(1,222,33,.5)}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.WhitespaceNormalization, :rgba_spaces})

      meta = get_atomic(rule.atomic_classes, "color")
      assert field(meta, :class) == "xe1l9yr"
      assert field(meta, :ltr) == ".xe1l9yr{color:rgba(1,222,33,.5)}"
      assert field(meta, :rtl) == nil
      assert field(meta, :priority) == 3000
    end
  end

  describe "zero values" do
    test "removes units from 0 length values" do
      # StyleX: ".x1ghz6dp{margin:0}" and ".xgsvwom{margin-left:1px}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_px})

      # margin: 0 (units removed)
      margin_meta = get_atomic(rule.atomic_classes, "margin")
      assert field(margin_meta, :class) == "x1ghz6dp"
      assert field(margin_meta, :ltr) == ".x1ghz6dp{margin:0}"
      assert field(margin_meta, :priority) == 1000

      # margin-left: 1px (units preserved for non-zero)
      margin_left_meta = get_atomic(rule.atomic_classes, "margin-left")
      assert field(margin_left_meta, :class) == "xgsvwom"
      assert field(margin_left_meta, :ltr) == ".xgsvwom{margin-left:1px}"
      assert field(margin_left_meta, :priority) == 4000
    end

    test "converts 0ms timing to 0s" do
      # StyleX: ".x1mq3mr6{transition-duration:0s}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_timing})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "x1mq3mr6"
      assert field(meta, :ltr) == ".x1mq3mr6{transition-duration:0s}"
      assert field(meta, :priority) == 3000
    end

    test "converts 0rad to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_angle_rad})

      meta = get_atomic(rule.atomic_classes, "transform")
      assert field(meta, :class) == "x1jpfit1"
      assert field(meta, :ltr) == ".x1jpfit1{transform:0deg}"
      assert field(meta, :priority) == 3000
    end

    test "converts 0turn to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_angle_turn})

      meta = get_atomic(rule.atomic_classes, "transform")
      assert field(meta, :class) == "x1jpfit1"
      assert field(meta, :ltr) == ".x1jpfit1{transform:0deg}"
      assert field(meta, :priority) == 3000
    end

    test "converts 0grad to 0deg" do
      # StyleX: ".x1jpfit1{transform:0deg}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_angle_grad})

      meta = get_atomic(rule.atomic_classes, "transform")
      assert field(meta, :class) == "x1jpfit1"
      assert field(meta, :ltr) == ".x1jpfit1{transform:0deg}"
      assert field(meta, :priority) == 3000
    end

    test "integer 0 normalizes to 0 without unit suffix" do
      # StyleX: margin: 0 -> ".x1ghz6dp{margin:0}" (not "0px")
      # This ensures numeric 0 values don't get px suffix before normalization
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ZeroValues, :zero_integer})

      # margin: 0 -> "0" (not "0px")
      margin_meta = get_atomic(rule.atomic_classes, "margin")
      assert field(margin_meta, :class) == "x1ghz6dp"
      assert field(margin_meta, :ltr) == ".x1ghz6dp{margin:0}"
      assert field(margin_meta, :priority) == 1000

      # padding: 0 -> "0" (not "0px")
      padding_meta = get_atomic(rule.atomic_classes, "padding")
      assert field(padding_meta, :class) == "x1717udv"
      assert field(padding_meta, :ltr) == ".x1717udv{padding:0}"
      assert field(padding_meta, :priority) == 1000
    end
  end

  describe "calc() values" do
    test "preserves spaces around + and - in calc()" do
      # StyleX: ".x1hauit9{width:calc((100% + 3% - 100px) / 7)}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.CalcValues, :calc_spaces})

      meta = get_atomic(rule.atomic_classes, "width")
      assert field(meta, :class) == "x1hauit9"
      assert field(meta, :ltr) == ".x1hauit9{width:calc((100% + 3% - 100px) / 7)}"
      assert field(meta, :priority) == 4000
    end

    test "nested calc() functions are preserved" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.CalcValues, :nested_calc})

      meta = get_atomic(rule.atomic_classes, "width")
      assert field(meta, :ltr) =~ "calc(100% - calc(20px + 10px))"
    end

    test "deeply nested calc() functions are preserved" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.CalcValues, :deeply_nested_calc})

      meta = get_atomic(rule.atomic_classes, "height")
      assert field(meta, :ltr) =~ "calc(50vh - calc(100% / calc(3 + 1)))"
    end

    test "calc() inside clamp() is preserved" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.CalcValues, :clamp_with_calc})

      meta = get_atomic(rule.atomic_classes, "padding")
      assert field(meta, :ltr) =~ "clamp(10px,calc(1rem + 2vw),30px)"
    end
  end

  describe "leading zeros" do
    test "strips leading zeros from decimal values" do
      # StyleX: ".xpvlhck{transition-duration:.01s}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.LeadingZeros, :decimal})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "xpvlhck"
      assert field(meta, :ltr) == ".xpvlhck{transition-duration:.01s}"
      assert field(meta, :priority) == 3000
    end

    test "cubic-bezier values strip leading zeros" do
      # StyleX: ".xxziih7{transition-timing-function:cubic-bezier(.08,.52,.52,1)}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.LeadingZeros, :cubic_bezier})

      meta = get_atomic(rule.atomic_classes, "transition-timing-function")
      assert field(meta, :class) == "xxziih7"

      assert field(meta, :ltr) ==
               ".xxziih7{transition-timing-function:cubic-bezier(.08,.52,.52,1)}"

      assert field(meta, :priority) == 3000
    end
  end

  describe "timing values" do
    test "converts 1234ms to 1.234s" do
      # StyleX: ".xsa3hc2{transition-duration:1.234s}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TimingValues, :ms_large})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "xsa3hc2"
      assert field(meta, :ltr) == ".xsa3hc2{transition-duration:1.234s}"
      assert field(meta, :priority) == 3000
    end

    test "converts 10ms to .01s" do
      # StyleX: ".xpvlhck{transition-duration:.01s}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TimingValues, :ms_medium})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "xpvlhck"
      assert field(meta, :ltr) == ".xpvlhck{transition-duration:.01s}"
      assert field(meta, :priority) == 3000
    end

    test "keeps 1ms as is (below 10ms threshold)" do
      # StyleX: ".xjd9b36{transition-duration:1ms}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TimingValues, :ms_small})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "xjd9b36"
      assert field(meta, :ltr) == ".xjd9b36{transition-duration:1ms}"
      assert field(meta, :priority) == 3000
    end

    test "converts 500ms to .5s" do
      # StyleX: ".x1wsgiic{transition-duration:.5s}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TimingValues, :ms_500})

      meta = get_atomic(rule.atomic_classes, "transition-duration")
      assert field(meta, :class) == "x1wsgiic"
      assert field(meta, :ltr) == ".x1wsgiic{transition-duration:.5s}"
      assert field(meta, :priority) == 3000
    end
  end

  describe "unitless vs unit-requiring properties" do
    test "adds px to height numeric value" do
      # StyleX: ".x1egiwwb{height:500px}" with priority 4000
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :with_units})

      meta = get_atomic(rule.atomic_classes, "height")
      assert field(meta, :class) == "x1egiwwb"
      assert field(meta, :ltr) == ".x1egiwwb{height:500px}"
      assert field(meta, :priority) == 4000
    end

    test "adds px to margin numeric value" do
      # StyleX: ".x1oin6zd{margin:10px}" with priority 1000
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :with_units})

      meta = get_atomic(rule.atomic_classes, "margin")
      assert field(meta, :class) == "x1oin6zd"
      assert field(meta, :ltr) == ".x1oin6zd{margin:10px}"
      assert field(meta, :priority) == 1000
    end

    test "adds px to width numeric value" do
      # StyleX: ".xvue9z{width:500px}" with priority 4000
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :with_units})

      meta = get_atomic(rule.atomic_classes, "width")
      assert field(meta, :class) == "xvue9z"
      assert field(meta, :ltr) == ".xvue9z{width:500px}"
      assert field(meta, :priority) == 4000
    end

    test "does not add units to font-weight" do
      # StyleX: ".xk50ysn{font-weight:500}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :unitless})

      meta = get_atomic(rule.atomic_classes, "font-weight")
      assert field(meta, :class) == "xk50ysn"
      assert field(meta, :ltr) == ".xk50ysn{font-weight:500}"
      assert field(meta, :priority) == 3000
    end

    test "does not add units to line-height" do
      # StyleX: ".x1evy7pa{line-height:1.5}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :unitless})

      meta = get_atomic(rule.atomic_classes, "line-height")
      assert field(meta, :class) == "x1evy7pa"
      assert field(meta, :ltr) == ".x1evy7pa{line-height:1.5}"
      assert field(meta, :priority) == 3000
    end

    test "strips leading zero from opacity and does not add units" do
      # StyleX: ".xbyyjgo{opacity:.5}"
      # Note: StyleX produces xbyyjgo but we might have different hash
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :unitless})

      meta = get_atomic(rule.atomic_classes, "opacity")
      # Opacity 0.5 should become .5 (leading zero stripped)
      assert field(meta, :ltr) =~ ~r/opacity:\.5\}/
      assert field(meta, :priority) == 3000
    end

    test "does not add units to zoom" do
      # StyleX: ".xy2o3ld{zoom:2}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.UnitlessValues, :unitless})

      meta = get_atomic(rule.atomic_classes, "zoom")
      assert field(meta, :class) == "xy2o3ld"
      assert field(meta, :ltr) == ".xy2o3ld{zoom:2}"
      assert field(meta, :priority) == 3000
    end
  end

  describe "number rounding" do
    test "rounds numbers to 4 decimal places" do
      # StyleX: ".x1vvwc6p{height:33.3333px}" with priority 4000
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.NumberRounding, :rounded})

      meta = get_atomic(rule.atomic_classes, "height")
      assert field(meta, :class) == "x1vvwc6p"
      assert field(meta, :ltr) == ".x1vvwc6p{height:33.3333px}"
      assert field(meta, :priority) == 4000
    end
  end

  describe "content property" do
    test "wraps empty content in quotes" do
      # StyleX: ".x14axycx{content:\"\"}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :empty})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :class) == "x14axycx"
      assert field(meta, :ltr) == ".x14axycx{content:\"\"}"
      assert field(meta, :priority) == 3000
    end

    test "wraps text content in quotes" do
      # StyleX: ".x1r2f195{content:\"hello\"}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :with_text})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :class) == "x1r2f195"
      assert field(meta, :ltr) == ".x1r2f195{content:\"hello\"}"
      assert field(meta, :priority) == 3000
    end

    test "does not wrap attr() function in quotes" do
      # StyleX does not wrap special functions like attr()
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :with_attr})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :class) == "xli7a2p"
      assert field(meta, :ltr) == ".xli7a2p{content:attr(data-count)}"
      assert field(meta, :priority) == 3000
    end

    test "does not wrap open-quote keyword in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :open_quote})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:open-quote\}/
    end

    test "does not wrap close-quote keyword in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :close_quote})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:close-quote\}/
    end

    test "does not wrap no-open-quote keyword in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :no_open_quote})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:no-open-quote\}/
    end

    test "does not wrap no-close-quote keyword in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :no_close_quote})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:no-close-quote\}/
    end

    test "does not wrap counter() function in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :counter_fn})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:counter\(section\)\}/
    end

    test "does not wrap counters() function in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :counters_fn})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:counters\(section/
    end

    test "does not wrap var() function in quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ContentProperty, :var_fn})

      meta = get_atomic(rule.atomic_classes, "content")
      assert field(meta, :ltr) =~ ~r/content:var\(--my-content\)\}/
    end
  end

  describe "hyphenate-character property" do
    test "auto keyword is not quoted" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.HyphenateCharacter, :auto})

      meta = get_atomic(rule.atomic_classes, "hyphenate-character")
      assert field(meta, :ltr) =~ ~r/hyphenate-character:auto\}/
    end

    test "dash character is quoted" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.HyphenateCharacter, :dash})

      meta = get_atomic(rule.atomic_classes, "hyphenate-character")
      assert field(meta, :ltr) =~ ~r/hyphenate-character:"-"\}/
    end

    test "custom character is quoted" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.HyphenateCharacter, :custom})

      meta = get_atomic(rule.atomic_classes, "hyphenate-character")
      assert field(meta, :ltr) =~ ~r/hyphenate-character:"="\}/
    end
  end

  describe "quotes property normalization" do
    test "single-quoted empty string normalizes to double quotes" do
      # StyleX: quotes: "''" -> ".x169joja{quotes:\"\"}"
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.QuotesProperty, :empty_single})

      meta = get_atomic(rule.atomic_classes, "quotes")
      assert field(meta, :class) == "x169joja"
      assert field(meta, :ltr) == ".x169joja{quotes:\"\"}"
      assert field(meta, :priority) == 3000
    end

    test "double-quoted empty string stays as double quotes" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.QuotesProperty, :empty_double})

      meta = get_atomic(rule.atomic_classes, "quotes")
      assert field(meta, :class) == "x169joja"
      assert field(meta, :ltr) == ".x169joja{quotes:\"\"}"
      assert field(meta, :priority) == 3000
    end
  end

  describe "transition-property value conversion" do
    test "converts atom snake_case to dash-case" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TransitionPropertyValues, :atom_single})

      meta = get_atomic(rule.atomic_classes, "transition-property")
      assert field(meta, :ltr) =~ ~r/transition-property:background-color\}/
    end

    test "preserves simple atom values" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TransitionPropertyValues, :atom_opacity})

      meta = get_atomic(rule.atomic_classes, "transition-property")
      assert field(meta, :ltr) =~ ~r/transition-property:opacity\}/
    end

    test "converts string snake_case to dash-case" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TransitionPropertyValues, :string_snake})

      meta = get_atomic(rule.atomic_classes, "transition-property")
      assert field(meta, :ltr) =~ ~r/transition-property:background-color\}/
    end

    test "converts multiple comma-separated snake_case values" do
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.TransitionPropertyValues, :string_multi})

      meta = get_atomic(rule.atomic_classes, "transition-property")
      # Should be "opacity,background-color,border-radius"
      assert field(meta, :ltr) =~ ~r/transition-property:opacity,background-color,border-radius\}/
    end

    test "preserves custom properties (does not convert underscores)" do
      rule =
        Class.lookup!(
          {LiveStyle.ValueNormalizationTest.TransitionPropertyValues, :string_custom_prop}
        )

      meta = get_atomic(rule.atomic_classes, "transition-property")
      # Custom props starting with -- should preserve underscores
      assert field(meta, :ltr) =~ ~r/transition-property:--my_custom_prop\}/
    end
  end

  describe "!important handling" do
    test "removes space before !important" do
      # StyleX: ".xzw3067{color:red!important}"
      # No space before !important
      rule =
        Class.lookup!({LiveStyle.ValueNormalizationTest.ImportantValues, :important})

      meta = get_atomic(rule.atomic_classes, "color")
      assert field(meta, :class) == "xzw3067"
      assert field(meta, :ltr) == ".xzw3067{color:red!important}"
      assert field(meta, :priority) == 3000
    end
  end
end
