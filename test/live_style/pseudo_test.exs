defmodule LiveStyle.PseudoTest do
  @moduledoc """
  Tests for pseudo-classes and pseudo-elements.

  This file mirrors StyleX's transform-stylex-create-test.js sections:
  - "object values: pseudo-classes"
  - "object values: pseudo-elements"

  Organized into:
  1. Basic pseudo-classes (:hover, :focus, :active)
  2. Form state pseudo-classes (:disabled, :checked, :valid, etc.)
  3. Focus variants (:focus-visible, :focus-within)
  4. Tree-structural pseudo-classes (:first-child, :nth-child, etc.)
  5. Link pseudo-classes (:link, :visited, :target)
  6. Functional pseudo-classes (:not, :is, :has, :where)
  7. Basic pseudo-elements (::before, ::after, ::placeholder)
  8. Extended pseudo-elements (::marker, ::selection, ::backdrop, etc.)
  9. Vendor-prefixed pseudo-elements (::thumb expansion)
  """
  use LiveStyle.TestCase
  use Snapshy

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.Class

  # ============================================================================
  # Test Modules - Basic Pseudo-Classes
  # ============================================================================

  defmodule BasicPseudoClasses do
    use LiveStyle

    class(:hover,
      background_color: [":hover": "red"],
      color: [":hover": "blue"]
    )

    class(:focus, color: [":focus": "yellow"])
    class(:active, color: [":active": "red"])

    class(:multiple_pseudos,
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
    class(:nested,
      color: [":hover": [":active": "red"]]
    )
  end

  # ============================================================================
  # Test Modules - Form State Pseudo-Classes
  # ============================================================================

  defmodule FormStatePseudoClasses do
    use LiveStyle

    class(:disabled,
      color: [default: "black", ":disabled": "gray"]
    )

    class(:enabled,
      opacity: [default: "1", ":enabled": "1", ":disabled": "0.5"]
    )

    class(:checked,
      background_color: [default: "white", ":checked": "blue"]
    )

    class(:indeterminate,
      background_color: [default: "white", ":indeterminate": "gray"]
    )

    class(:valid,
      border_color: [default: "gray", ":valid": "green"]
    )

    class(:invalid,
      border_color: [default: "gray", ":invalid": "red"]
    )

    class(:required,
      border_style: [default: "solid", ":required": "dashed"]
    )

    class(:optional,
      border_style: [default: "solid", ":optional": "dotted"]
    )

    class(:read_only,
      background_color: [default: "white", ":read-only": "#f5f5f5"]
    )

    class(:placeholder_shown,
      color: [default: "black", ":placeholder-shown": "#999"]
    )

    class(:in_range,
      border_color: [default: "gray", ":in-range": "green"]
    )

    class(:out_of_range,
      border_color: [default: "gray", ":out-of-range": "red"]
    )
  end

  # ============================================================================
  # Test Modules - Focus Variants
  # ============================================================================

  defmodule FocusPseudoClasses do
    use LiveStyle

    class(:focus_visible,
      outline: [default: "none", ":focus-visible": "2px solid blue"]
    )

    class(:focus_within,
      border_color: [default: "gray", ":focus-within": "blue"]
    )
  end

  # ============================================================================
  # Test Modules - Tree-Structural Pseudo-Classes
  # ============================================================================

  defmodule TreeStructuralPseudoClasses do
    use LiveStyle

    class(:first_child,
      margin_top: [default: "1rem", ":first-child": "0"]
    )

    class(:last_child,
      margin_bottom: [default: "1rem", ":last-child": "0"]
    )

    class(:only_child,
      margin: [default: "1rem", ":only-child": "0"]
    )

    class(:first_of_type,
      font_weight: [default: "normal", ":first-of-type": "bold"]
    )

    class(:last_of_type,
      font_style: [default: "normal", ":last-of-type": "italic"]
    )

    class(:only_of_type,
      color: [default: "black", ":only-of-type": "blue"]
    )

    class(:nth_child_odd,
      background_color: [default: "white", ":nth-child(odd)": "#f0f0f0"]
    )

    class(:nth_child_even,
      background_color: [default: "white", ":nth-child(even)": "#e0e0e0"]
    )

    class(:nth_child_formula,
      background_color: [default: "white", ":nth-child(2n+1)": "#f0f0f0"]
    )

    class(:nth_last_child,
      opacity: [default: "1", ":nth-last-child(2)": "0.8"]
    )

    class(:nth_of_type,
      color: [default: "black", ":nth-of-type(3)": "red"]
    )
  end

  # ============================================================================
  # Test Modules - Link Pseudo-Classes
  # ============================================================================

  defmodule LinkPseudoClasses do
    use LiveStyle

    class(:link,
      color: [default: "blue", ":link": "blue", ":visited": "purple"]
    )

    class(:any_link,
      text_decoration: [default: "none", ":any-link": "underline"]
    )

    class(:target,
      background_color: [default: "transparent", ":target": "yellow"]
    )
  end

  # ============================================================================
  # Test Modules - Other Pseudo-Classes
  # ============================================================================

  defmodule OtherPseudoClasses do
    use LiveStyle

    class(:empty,
      display: [default: "block", ":empty": "none"]
    )

    class(:autofill,
      background_color: [default: "white", ":autofill": "#e8f0fe"]
    )

    class(:fullscreen,
      width: [default: "auto", ":fullscreen": "100vw"]
    )

    class(:modal,
      z_index: [default: "auto", ":modal": "9999"]
    )
  end

  # ============================================================================
  # Test Modules - Functional Pseudo-Classes
  # ============================================================================

  defmodule FunctionalPseudoClasses do
    use LiveStyle

    class(:not_disabled,
      opacity: [default: "1", ":not(:disabled)": "1"]
    )

    class(:is_hover_focus,
      color: [default: "black", ":is(:hover, :focus)": "blue"]
    )

    class(:where_hover,
      color: [default: "black", ":where(:hover)": "blue"]
    )

    class(:has_focus,
      border_color: [default: "gray", ":has(:focus)": "blue"]
    )
  end

  # ============================================================================
  # Test Modules - Basic Pseudo-Elements
  # ============================================================================

  defmodule BasicPseudoElements do
    use LiveStyle

    class(:before,
      "::before": [color: "red"]
    )

    class(:after,
      "::after": [content: "hello", color: "blue"]
    )

    class(:placeholder,
      "::placeholder": [color: "gray"]
    )
  end

  defmodule PseudoElementWithPseudoClass do
    use LiveStyle

    class(:before_hover,
      "::before": [color: [default: "red", ":hover": "blue"]]
    )
  end

  # ============================================================================
  # Test Modules - Extended Pseudo-Elements
  # ============================================================================

  defmodule MarkerStyles do
    use LiveStyle

    class(:marker,
      "::marker": [color: "red", font_size: "1.2em"]
    )
  end

  defmodule SelectionStyles do
    use LiveStyle

    class(:selection,
      "::selection": [background_color: "yellow", color: "black"]
    )

    class(:selection_hover,
      "::selection": [background_color: [default: "blue", ":hover": "darkblue"]]
    )
  end

  defmodule BackdropStyles do
    use LiveStyle

    class(:backdrop,
      "::backdrop": [background_color: "rgba(0,0,0,0.7)"]
    )
  end

  defmodule FirstLetterLineStyles do
    use LiveStyle

    class(:first_letter,
      "::first-letter": [font_size: "2em", font_weight: "bold"]
    )

    class(:first_line,
      "::first-line": [font_weight: "bold", text_decoration: "underline"]
    )
  end

  defmodule FileSelectorStyles do
    use LiveStyle

    class(:file_button,
      "::file-selector-button": [background_color: "blue", color: "white", padding: "8px 16px"]
    )
  end

  defmodule WebkitScrollbarStyles do
    use LiveStyle

    class(:scrollbar,
      "::-webkit-scrollbar": [width: "8px"]
    )

    class(:scrollbar_thumb,
      "::-webkit-scrollbar-thumb": [background_color: "gray", border_radius: "4px"]
    )

    class(:scrollbar_track,
      "::-webkit-scrollbar-track": [background_color: "#f1f1f1"]
    )
  end

  defmodule CueStyles do
    use LiveStyle

    class(:cue,
      "::cue": [color: "white", background_color: "black"]
    )
  end

  # ============================================================================
  # Test Modules - Vendor-Prefixed Pseudo-Elements
  # ============================================================================

  defmodule ThumbPseudoElement do
    use LiveStyle

    # StyleX expands ::thumb to vendor-prefixed variants:
    # ::-webkit-slider-thumb, ::-moz-range-thumb, ::-ms-thumb
    class(:slider_thumb,
      "::thumb": [width: 16]
    )

    class(:slider_thumb_styled,
      "::thumb": [width: 20, height: 20, background_color: "blue", border_radius: "50%"]
    )
  end

  # ============================================================================
  # Snapshot Tests - Basic Pseudo-Classes
  # ============================================================================

  describe "basic pseudo-classes" do
    test_snapshot ":hover pseudo-class CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoClasses, [:hover])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot ":focus pseudo-class CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoClasses, [:focus])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot ":active pseudo-class CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoClasses, [:active])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "multiple pseudo-classes on same property" do
      class_string = Compiler.get_css_class(BasicPseudoClasses, [:multiple_pseudos])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  describe "nested pseudo-classes" do
    test_snapshot "nested :hover :active generates sorted selector" do
      # StyleX sorts pseudo-classes alphabetically: :active:hover (not :hover:active)
      class_string = Compiler.get_css_class(NestedPseudoClasses, [:nested])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Basic Pseudo-Elements
  # ============================================================================

  describe "basic pseudo-elements" do
    test_snapshot "::before pseudo-element CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoElements, [:before])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "::after pseudo-element CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoElements, [:after])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "::placeholder pseudo-element CSS output" do
      class_string = Compiler.get_css_class(BasicPseudoElements, [:placeholder])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  describe "pseudo-element with pseudo-class" do
    test_snapshot "::before containing :hover CSS output" do
      class_string =
        Compiler.get_css_class(PseudoElementWithPseudoClass, [:before_hover])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Vendor-Prefixed Pseudo-Elements
  # ============================================================================

  describe "::thumb pseudo-element expansion" do
    test_snapshot "::thumb expands to vendor prefixes" do
      class_string = Compiler.get_css_class(ThumbPseudoElement, [:slider_thumb])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "::thumb with multiple properties" do
      class_string = Compiler.get_css_class(ThumbPseudoElement, [:slider_thumb_styled])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "::thumb generates vendor-prefixed selectors" do
      css = Compiler.generate_css()

      # Should have all three vendor-prefixed selectors
      assert css =~ "::-webkit-slider-thumb"
      assert css =~ "::-moz-range-thumb"
      assert css =~ "::-ms-thumb"

      # Should be comma-separated in a single rule
      assert css =~ ~r/::-webkit-slider-thumb,.*::-moz-range-thumb,.*::-ms-thumb/
    end
  end

  # ============================================================================
  # Priority Tests - Form State Pseudo-Classes
  # ============================================================================

  describe "form state pseudo-class priorities" do
    test ":disabled has priority offset 92" do
      rule = Class.lookup!({FormStatePseudoClasses, :disabled})
      disabled = rule.atomic_classes["color"].classes[":disabled"]
      assert disabled.ltr =~ ":disabled{color:gray}"
      # 3000 (color) + 92 (:disabled) = 3092
      assert disabled.priority == 3092
    end

    test ":enabled has priority offset 91" do
      rule = Class.lookup!({FormStatePseudoClasses, :enabled})
      enabled = rule.atomic_classes["opacity"].classes[":enabled"]
      # 3000 (opacity) + 91 (:enabled) = 3091
      assert enabled.priority == 3091
    end

    test ":checked has priority offset 101" do
      rule = Class.lookup!({FormStatePseudoClasses, :checked})
      checked = rule.atomic_classes["background-color"].classes[":checked"]
      # 3000 (background-color) + 101 (:checked) = 3101
      assert checked.priority == 3101
    end

    test ":valid has priority offset 103" do
      rule = Class.lookup!({FormStatePseudoClasses, :valid})
      valid = rule.atomic_classes["border-color"].classes[":valid"]
      # 2000 (border-color shorthand) + 103 (:valid) = 2103
      assert valid.priority == 2103
    end

    test ":invalid has priority offset 104" do
      rule = Class.lookup!({FormStatePseudoClasses, :invalid})
      invalid = rule.atomic_classes["border-color"].classes[":invalid"]
      # 2000 (border-color shorthand) + 104 (:invalid) = 2104
      assert invalid.priority == 2104
    end

    test ":required has priority offset 93" do
      rule = Class.lookup!({FormStatePseudoClasses, :required})
      required = rule.atomic_classes["border-style"].classes[":required"]
      # 2000 (border-style shorthand) + 93 (:required) = 2093
      assert required.priority == 2093
    end

    test ":placeholder-shown has priority offset 97" do
      rule = Class.lookup!({FormStatePseudoClasses, :placeholder_shown})
      ps = rule.atomic_classes["color"].classes[":placeholder-shown"]
      # 3000 (color) + 97 (:placeholder-shown) = 3097
      assert ps.priority == 3097
    end
  end

  # ============================================================================
  # Priority Tests - Focus Variants
  # ============================================================================

  describe "focus variant pseudo-class priorities" do
    test ":focus-visible has priority offset 160" do
      rule = Class.lookup!({FocusPseudoClasses, :focus_visible})
      fv = rule.atomic_classes["outline"].classes[":focus-visible"]
      assert fv.ltr =~ ":focus-visible{outline:2px solid blue}"
      # 2000 (outline shorthand) + 160 (:focus-visible) = 2160
      assert fv.priority == 2160
    end

    test ":focus-within has priority offset 140" do
      rule = Class.lookup!({FocusPseudoClasses, :focus_within})
      fw = rule.atomic_classes["border-color"].classes[":focus-within"]
      # 2000 (border-color shorthand) + 140 (:focus-within) = 2140
      assert fw.priority == 2140
    end
  end

  # ============================================================================
  # Priority Tests - Tree-Structural Pseudo-Classes
  # ============================================================================

  describe "tree-structural pseudo-class priorities" do
    test ":first-child has priority offset 52" do
      rule = Class.lookup!({TreeStructuralPseudoClasses, :first_child})
      fc = rule.atomic_classes["margin-top"].classes[":first-child"]
      # 4000 (margin-top physical) + 52 (:first-child) = 4052
      assert fc.priority == 4052
    end

    test ":last-child has priority offset 54" do
      rule = Class.lookup!({TreeStructuralPseudoClasses, :last_child})
      lc = rule.atomic_classes["margin-bottom"].classes[":last-child"]
      # 4000 (margin-bottom physical) + 54 (:last-child) = 4054
      assert lc.priority == 4054
    end

    test ":only-child has priority offset 56" do
      rule = Class.lookup!({TreeStructuralPseudoClasses, :only_child})
      oc = rule.atomic_classes["margin"].classes[":only-child"]
      # 1000 (margin shorthand) + 56 (:only-child) = 1056
      assert oc.priority == 1056
    end

    test ":nth-child functional has priority offset 60" do
      rule = Class.lookup!({TreeStructuralPseudoClasses, :nth_child_odd})
      nth = rule.atomic_classes["background-color"].classes[":nth-child(odd)"]
      # 3000 (background-color) + 60 (:nth-child) = 3060
      assert nth.priority == 3060
    end

    test ":nth-last-child has priority offset 61" do
      rule = Class.lookup!({TreeStructuralPseudoClasses, :nth_last_child})
      nlc = rule.atomic_classes["opacity"].classes[":nth-last-child(2)"]
      # 3000 (opacity) + 61 (:nth-last-child) = 3061
      assert nlc.priority == 3061
    end
  end

  # ============================================================================
  # Priority Tests - Link Pseudo-Classes
  # ============================================================================

  describe "link pseudo-class priorities" do
    test ":link has priority offset 80" do
      rule = Class.lookup!({LinkPseudoClasses, :link})
      link = rule.atomic_classes["color"].classes[":link"]
      # 3000 (color) + 80 (:link) = 3080
      assert link.priority == 3080
    end

    test ":visited has priority offset 85" do
      rule = Class.lookup!({LinkPseudoClasses, :link})
      visited = rule.atomic_classes["color"].classes[":visited"]
      # 3000 (color) + 85 (:visited) = 3085
      assert visited.priority == 3085
    end

    test ":target has priority offset 84" do
      rule = Class.lookup!({LinkPseudoClasses, :target})
      target = rule.atomic_classes["background-color"].classes[":target"]
      # 3000 (background-color) + 84 (:target) = 3084
      assert target.priority == 3084
    end
  end

  # ============================================================================
  # Priority Tests - Other Pseudo-Classes
  # ============================================================================

  describe "other pseudo-class priorities" do
    test ":empty has priority offset 70" do
      rule = Class.lookup!({OtherPseudoClasses, :empty})
      empty = rule.atomic_classes["display"].classes[":empty"]
      # 3000 (display) + 70 (:empty) = 3070
      assert empty.priority == 3070
    end

    test ":autofill has priority offset 110" do
      rule = Class.lookup!({OtherPseudoClasses, :autofill})
      autofill = rule.atomic_classes["background-color"].classes[":autofill"]
      # 3000 (background-color) + 110 (:autofill) = 3110
      assert autofill.priority == 3110
    end

    test ":fullscreen has priority offset 122" do
      rule = Class.lookup!({OtherPseudoClasses, :fullscreen})
      fs = rule.atomic_classes["width"].classes[":fullscreen"]
      # 4000 (width physical) + 122 (:fullscreen) = 4122
      assert fs.priority == 4122
    end
  end

  # ============================================================================
  # Priority Tests - Functional Pseudo-Classes
  # ============================================================================

  describe "functional pseudo-class priorities" do
    test ":not() has priority offset 40" do
      rule = Class.lookup!({FunctionalPseudoClasses, :not_disabled})
      not_dis = rule.atomic_classes["opacity"].classes[":not(:disabled)"]
      # 3000 (opacity) + 40 (:not) = 3040
      assert not_dis.priority == 3040
    end

    test ":is() has priority offset 40" do
      rule = Class.lookup!({FunctionalPseudoClasses, :is_hover_focus})
      is_hf = rule.atomic_classes["color"].classes[":is(:hover, :focus)"]
      # 3000 (color) + 40 (:is) = 3040
      assert is_hf.priority == 3040
    end

    test ":where() has priority offset 40" do
      rule = Class.lookup!({FunctionalPseudoClasses, :where_hover})
      where_h = rule.atomic_classes["color"].classes[":where(:hover)"]
      # 3000 (color) + 40 (:where) = 3040
      assert where_h.priority == 3040
    end

    test ":has() has priority offset 45" do
      rule = Class.lookup!({FunctionalPseudoClasses, :has_focus})
      has_f = rule.atomic_classes["border-color"].classes[":has(:focus)"]
      # 2000 (border-color shorthand) + 45 (:has) = 2045
      assert has_f.priority == 2045
    end
  end

  # ============================================================================
  # Priority Tests - Extended Pseudo-Elements
  # ============================================================================

  describe "pseudo-element priorities" do
    test "::marker has base priority 8000" do
      rule = Class.lookup!({MarkerStyles, :marker})
      color_meta = rule.atomic_classes["color::marker"]
      assert color_meta.ltr =~ "::marker{color:red}"
      assert color_meta.priority == 8000
    end

    test "::selection has base priority 8000" do
      rule = Class.lookup!({SelectionStyles, :selection})
      bg_meta = rule.atomic_classes["background-color::selection"]
      assert bg_meta.ltr =~ "::selection{background-color:yellow}"
      assert bg_meta.priority == 8000
    end

    test "::backdrop has base priority 8000" do
      rule = Class.lookup!({BackdropStyles, :backdrop})
      bg_meta = rule.atomic_classes["background-color::backdrop"]
      assert bg_meta.ltr =~ "::backdrop{background-color:rgba(0,0,0,.7)}"
      assert bg_meta.priority == 8000
    end

    test "::first-letter has base priority 8000" do
      rule = Class.lookup!({FirstLetterLineStyles, :first_letter})
      font_size = rule.atomic_classes["font-size::first-letter"]
      assert font_size.ltr =~ "::first-letter{font-size:2em}"
      assert font_size.priority == 8000
    end

    test "::first-line shorthand has priority 7000 (2000 + 5000)" do
      rule = Class.lookup!({FirstLetterLineStyles, :first_line})
      text_dec = rule.atomic_classes["text-decoration::first-line"]
      assert text_dec.ltr =~ "::first-line{text-decoration:underline}"
      # text-decoration is a shorthand (priority 2000), so 2000 + 5000 = 7000
      assert text_dec.priority == 7000
    end

    test "::-webkit-scrollbar has priority 9000" do
      rule = Class.lookup!({WebkitScrollbarStyles, :scrollbar})
      width_meta = rule.atomic_classes["width::-webkit-scrollbar"]
      assert width_meta.ltr =~ "::-webkit-scrollbar{width:8px}"
      assert width_meta.priority == 9000
    end

    test "::selection:hover has combined priority 8130" do
      rule = Class.lookup!({SelectionStyles, :selection_hover})
      hover_meta = rule.atomic_classes["background-color::selection:hover"]
      assert hover_meta.ltr =~ "::selection:hover{background-color:darkblue}"
      # Priority: 8000 (::selection) + 130 (:hover) = 8130
      assert hover_meta.priority == 8130
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp extract_all_rules(class_string) do
    css = Compiler.generate_css()

    class_string
    |> String.split(" ")
    |> Enum.flat_map(fn class_name ->
      extract_rules_for_class(css, class_name)
    end)
    |> Enum.uniq()
  end

  defp extract_rules_for_class(css, class_name) do
    escaped_class = Regex.escape(class_name)

    patterns = [
      # Simple and pseudo-class rules
      ~r/\.#{escaped_class}(?::[^{]+)?\{[^}]+\}/,
      # Vendor-prefixed combo selectors (like ::thumb expansion)
      ~r/\.#{escaped_class}::-webkit[^,]+,\s*\.#{escaped_class}::-moz[^,]+,\s*\.#{escaped_class}::-ms[^{]+\{[^}]+\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, css) |> List.flatten()
    end)
  end
end
