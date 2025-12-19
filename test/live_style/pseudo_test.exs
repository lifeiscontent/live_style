defmodule LiveStyle.PseudoTest do
  @moduledoc """
  Tests for pseudo-classes and pseudo-elements.

  These tests mirror StyleX's transform-stylex-create-test.js pseudo-class
  and pseudo-element sections to ensure LiveStyle handles them the same way.
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Pseudo Classes
  # ============================================================================

  defmodule PseudoClasses do
    use LiveStyle

    css_class(:hover,
      background_color: {:":hover", "red"},
      color: {:":hover", "blue"}
    )

    css_class(:focus, color: {:":focus", "yellow"})
    css_class(:active, color: {:":active", "red"})

    # Multiple pseudo-classes on same property
    css_class(:multiple_pseudos,
      color: [
        default: "black",
        ":hover": "blue",
        ":active": "red",
        ":focus": "yellow"
      ]
    )
  end

  defmodule NestedPseudoClasses do
    use LiveStyle

    # Nested pseudo-classes: :hover + :active
    css_class(:nested,
      color: {:":hover", {:":active", "red"}}
    )
  end

  # ============================================================================
  # Pseudo Elements
  # ============================================================================

  defmodule PseudoElements do
    use LiveStyle

    css_class(:before,
      "::before": [
        color: "red"
      ]
    )

    css_class(:after,
      "::after": [
        content: "hello",
        color: "blue"
      ]
    )

    css_class(:placeholder,
      "::placeholder": [
        color: "gray"
      ]
    )
  end

  defmodule PseudoElementWithPseudoClass do
    use LiveStyle

    # ::before with :hover inside
    css_class(:before_hover,
      "::before": [
        color: "red",
        color: {:":hover", "blue"}
      ]
    )
  end

  # ============================================================================
  # Thumb Pseudo Element (Vendor Prefixed)
  # ============================================================================

  defmodule ThumbPseudoElement do
    use LiveStyle

    # StyleX expands ::thumb to vendor-prefixed variants:
    # ::-webkit-slider-thumb, ::-moz-range-thumb, ::-ms-thumb
    css_class(:slider_thumb,
      "::thumb": [
        width: 16
      ]
    )

    css_class(:slider_thumb_styled,
      "::thumb": [
        width: 20,
        height: 20,
        background_color: "blue",
        border_radius: "50%"
      ]
    )
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "pseudo-classes" do
    test "generates CSS with :hover pseudo-class" do
      # StyleX: ".x1gykpug:hover{background-color:red}" with priority 3130
      # StyleX: ".x17z2mba:hover{color:blue}" with priority 3130
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoClasses, {:class, :hover})

      # background-color:hover
      bg_meta = rule.atomic_classes["background-color"].classes[":hover"]
      assert bg_meta.class == "x1gykpug"
      assert bg_meta.ltr == ".x1gykpug:hover{background-color:red}"
      assert bg_meta.rtl == nil
      assert bg_meta.priority == 3130

      # color:hover
      color_meta = rule.atomic_classes["color"].classes[":hover"]
      assert color_meta.class == "x17z2mba"
      assert color_meta.ltr == ".x17z2mba:hover{color:blue}"
      assert color_meta.rtl == nil
      assert color_meta.priority == 3130
    end

    test "generates CSS with :focus pseudo-class" do
      # StyleX: ".x1wvtd7d:focus{color:yellow}" with priority 3150
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoClasses, {:class, :focus})

      meta = rule.atomic_classes["color"].classes[":focus"]
      assert meta.class == "x1wvtd7d"
      assert meta.ltr == ".x1wvtd7d:focus{color:yellow}"
      assert meta.rtl == nil
      assert meta.priority == 3150
    end

    test "generates CSS with :active pseudo-class" do
      # StyleX: ".x96fq8s:active{color:red}" with priority 3170
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoClasses, {:class, :active})

      meta = rule.atomic_classes["color"].classes[":active"]
      assert meta.class == "x96fq8s"
      assert meta.ltr == ".x96fq8s:active{color:red}"
      assert meta.rtl == nil
      assert meta.priority == 3170
    end

    test "generates multiple pseudo-classes with correct priority ordering" do
      # StyleX priorities:
      # :hover = 3130
      # :focus = 3150
      # :active = 3170
      rule =
        LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoClasses, {:class, :multiple_pseudos})

      classes = rule.atomic_classes["color"].classes

      # Default: 3000
      default = classes[:default]
      assert default.class == "x1mqxbix"
      assert default.ltr == ".x1mqxbix{color:black}"
      assert default.priority == 3000

      # :hover = 3130
      hover = classes[":hover"]
      assert hover.class == "x17z2mba"
      assert hover.ltr == ".x17z2mba:hover{color:blue}"
      assert hover.priority == 3130

      # :active = 3170
      active = classes[":active"]
      assert active.class == "x96fq8s"
      assert active.ltr == ".x96fq8s:active{color:red}"
      assert active.priority == 3170

      # :focus = 3150
      focus = classes[":focus"]
      assert focus.class == "x1wvtd7d"
      assert focus.ltr == ".x1wvtd7d:focus{color:yellow}"
      assert focus.priority == 3150
    end
  end

  describe "nested pseudo-classes" do
    test "generates CSS with nested pseudo-classes matching StyleX exactly" do
      # StyleX test: transform-stylex-create-test.js "pseudo-class generated order (nested, same value)"
      # Input: { color: { ':hover': { ':active': 'red' }, ':active': { ':hover': 'red' } } }
      # Expected:
      #   class = "xa2ikkt"
      #   ltr = ".xa2ikkt:active:hover{color:red}"  (sorted alphabetically!)
      #   priority = 3300 (3000 + 130 + 170)
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.NestedPseudoClasses, {:class, :nested})

      # The nested :hover -> :active produces combined selector
      # StyleX sorts pseudo-classes alphabetically: :active:hover (not :hover:active)
      meta = rule.atomic_classes["color"].classes[":hover:active"]
      assert meta.class == "xa2ikkt"
      assert meta.ltr == ".xa2ikkt:active:hover{color:red}"
      assert meta.rtl == nil
      assert meta.priority == 3300
    end
  end

  describe "pseudo-elements" do
    test "generates CSS with ::before pseudo-element" do
      # StyleX: ".x16oeupf::before{color:red}" with priority 8000
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoElements, {:class, :before})

      # Key format is "property::pseudo-element"
      meta = rule.atomic_classes["color::before"]
      assert meta.class == "x16oeupf"
      assert meta.ltr == ".x16oeupf::before{color:red}"
      assert meta.rtl == nil
      assert meta.priority == 8000
    end

    test "generates CSS with ::after pseudo-element" do
      # StyleX: ".xdaarc3::after{color:blue}" with priority 8000
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoElements, {:class, :after})

      color_meta = rule.atomic_classes["color::after"]
      assert color_meta.class == "xdaarc3"
      assert color_meta.ltr == ".xdaarc3::after{color:blue}"
      assert color_meta.rtl == nil
      assert color_meta.priority == 8000

      # Content should be quoted: ".x18bz22m::after{content:\"hello\"}"
      content_meta = rule.atomic_classes["content::after"]
      assert content_meta.class == "x18bz22m"
      assert content_meta.ltr == ".x18bz22m::after{content:\"hello\"}"
      assert content_meta.rtl == nil
      assert content_meta.priority == 8000
    end

    test "generates CSS with ::placeholder pseudo-element" do
      # StyleX: ".x6yu8oj::placeholder{color:gray}" with priority 8000
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoElements, {:class, :placeholder})

      meta = rule.atomic_classes["color::placeholder"]
      assert meta.class == "x6yu8oj"
      assert meta.ltr == ".x6yu8oj::placeholder{color:gray}"
      assert meta.rtl == nil
      assert meta.priority == 8000
    end
  end

  describe "pseudo-element with pseudo-class" do
    test "generates CSS with ::before containing :hover matching StyleX exactly" do
      # StyleX test: transform-stylex-create-test.js "::before containing pseudo-classes"
      # Input: { '::before': { color: { default: 'red', ':hover': 'blue' } } }
      # Expected:
      #   x16oeupf: { ltr: ".x16oeupf::before{color:red}", priority: 8000 }
      #   xeb2lg0: { ltr: ".xeb2lg0::before:hover{color:blue}", priority: 8130 }
      rule =
        LiveStyle.get_metadata(
          LiveStyle.PseudoTest.PseudoElementWithPseudoClass,
          {:class, :before_hover}
        )

      # ::before default color
      default_meta = rule.atomic_classes["color::before"]
      assert default_meta.class == "x16oeupf"
      assert default_meta.ltr == ".x16oeupf::before{color:red}"
      assert default_meta.priority == 8000

      # ::before:hover color - key is "color::before:hover"
      hover_meta = rule.atomic_classes["color::before:hover"]
      assert hover_meta.class == "xeb2lg0"
      assert hover_meta.ltr == ".xeb2lg0::before:hover{color:blue}"
      assert hover_meta.rtl == nil
      assert hover_meta.priority == 8130
    end
  end

  describe "::thumb pseudo-element expansion" do
    # StyleX expands ::thumb to vendor-prefixed selectors:
    # ::-webkit-slider-thumb, ::-moz-range-thumb, ::-ms-thumb
    # Reference: transform-stylex-create-test.js '"::thumb"' test

    test "generates CSS with ::thumb expanded to vendor prefixes" do
      # StyleX output:
      # ".x1en94km::-webkit-slider-thumb, .x1en94km::-moz-range-thumb, .x1en94km::-ms-thumb{width:16px}"
      # priority: 9000 (5000 pseudo-element + 4000 width longhand physical)
      css = generate_css()

      # Should have all three vendor-prefixed selectors
      assert css =~ "::-webkit-slider-thumb"
      assert css =~ "::-moz-range-thumb"
      assert css =~ "::-ms-thumb"

      # Should be comma-separated in a single rule
      assert css =~ ~r/::-webkit-slider-thumb,.*::-moz-range-thumb,.*::-ms-thumb/
    end

    test "::thumb has correct priority (9000 for width)" do
      # Priority = 5000 (pseudo-element) + 4000 (width is longhand physical) = 9000
      rule =
        LiveStyle.get_metadata(LiveStyle.PseudoTest.ThumbPseudoElement, {:class, :slider_thumb})

      meta = rule.atomic_classes["width::thumb"]
      assert meta.priority == 9000
    end

    test "::thumb works with multiple properties" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.PseudoTest.ThumbPseudoElement,
          {:class, :slider_thumb_styled}
        )

      # All properties should have ::thumb pseudo-element
      assert rule.atomic_classes["width::thumb"] != nil
      assert rule.atomic_classes["height::thumb"] != nil
      assert rule.atomic_classes["background-color::thumb"] != nil
      assert rule.atomic_classes["border-radius::thumb"] != nil
    end

    test "prefix_selector expands ::thumb correctly" do
      # Direct test of the helper function
      expanded = LiveStyle.CSS.prefix_selector(".x123::thumb")

      assert expanded ==
               ".x123::-webkit-slider-thumb, .x123::-moz-range-thumb, .x123::-ms-thumb"
    end

    test "prefix_selector passes through non-prefixable selectors" do
      assert LiveStyle.CSS.prefix_selector(".x123:hover") == ".x123:hover"
      assert LiveStyle.CSS.prefix_selector(".x123::before") == ".x123::before"
    end
  end

  describe "pseudo priority system" do
    # StyleX priority offsets:
    # :first-child = 10, :last-child = 20, :only-child = 30
    # :nth-child = 60, :nth-last-child = 70
    # :hover = 130, :focus = 150, :active = 170

    test ":hover has priority offset of 130" do
      assert LiveStyle.Priority.get_pseudo_priority(":hover") == 130
    end

    test ":focus has priority offset of 150" do
      assert LiveStyle.Priority.get_pseudo_priority(":focus") == 150
    end

    test ":active has priority offset of 170" do
      assert LiveStyle.Priority.get_pseudo_priority(":active") == 170
    end

    test "pseudo-element base priority is 8000" do
      rule = LiveStyle.get_metadata(LiveStyle.PseudoTest.PseudoElements, {:class, :before})

      meta = rule.atomic_classes["color::before"]
      assert meta.priority == 8000
    end
  end
end
