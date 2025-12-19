defmodule LiveStyle.PseudoClassesTest do
  @moduledoc """
  Tests for additional pseudo-classes beyond :hover, :active, :focus.

  These tests verify StyleX-compatible pseudo-class handling for:
  - Form states (:disabled, :enabled, :checked, :valid, :invalid, etc.)
  - Focus variants (:focus-visible, :focus-within)
  - Tree-structural (:first-child, :last-child, :nth-child, :only-child)
  - Link states (:visited, :link)
  - Other pseudo-classes (:empty, :target, :required, :optional)
  - Functional pseudo-classes (:not(), :is(), :has())

  ## StyleX Reference
  Each pseudo-class has a specific priority offset defined in
  packages/@stylexjs/shared/src/utils/property-priorities.js
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Test Modules - Form State Pseudo-Classes
  # ============================================================================

  defmodule FormStatePseudoClasses do
    use LiveStyle

    css_class(:disabled,
      color: [
        default: "black",
        ":disabled": "gray"
      ]
    )

    css_class(:enabled,
      opacity: [
        default: "1",
        ":enabled": "1",
        ":disabled": "0.5"
      ]
    )

    css_class(:checked,
      background_color: [
        default: "white",
        ":checked": "blue"
      ]
    )

    css_class(:indeterminate,
      background_color: [
        default: "white",
        ":indeterminate": "gray"
      ]
    )

    css_class(:valid,
      border_color: [
        default: "gray",
        ":valid": "green"
      ]
    )

    css_class(:invalid,
      border_color: [
        default: "gray",
        ":invalid": "red"
      ]
    )

    css_class(:required,
      border_style: [
        default: "solid",
        ":required": "dashed"
      ]
    )

    css_class(:optional,
      border_style: [
        default: "solid",
        ":optional": "dotted"
      ]
    )

    css_class(:read_only,
      background_color: [
        default: "white",
        ":read-only": "#f5f5f5"
      ]
    )

    css_class(:read_write,
      background_color: [
        default: "white",
        ":read-write": "white"
      ]
    )

    css_class(:placeholder_shown,
      color: [
        default: "black",
        ":placeholder-shown": "#999"
      ]
    )

    css_class(:in_range,
      border_color: [
        default: "gray",
        ":in-range": "green"
      ]
    )

    css_class(:out_of_range,
      border_color: [
        default: "gray",
        ":out-of-range": "red"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Focus Variants
  # ============================================================================

  defmodule FocusPseudoClasses do
    use LiveStyle

    css_class(:focus_visible,
      outline: [
        default: "none",
        ":focus-visible": "2px solid blue"
      ]
    )

    css_class(:focus_within,
      border_color: [
        default: "gray",
        ":focus-within": "blue"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Tree-Structural Pseudo-Classes
  # ============================================================================

  defmodule TreeStructuralPseudoClasses do
    use LiveStyle

    css_class(:first_child,
      margin_top: [
        default: "1rem",
        ":first-child": "0"
      ]
    )

    css_class(:last_child,
      margin_bottom: [
        default: "1rem",
        ":last-child": "0"
      ]
    )

    css_class(:only_child,
      margin: [
        default: "1rem",
        ":only-child": "0"
      ]
    )

    css_class(:first_of_type,
      font_weight: [
        default: "normal",
        ":first-of-type": "bold"
      ]
    )

    css_class(:last_of_type,
      font_style: [
        default: "normal",
        ":last-of-type": "italic"
      ]
    )

    css_class(:only_of_type,
      color: [
        default: "black",
        ":only-of-type": "blue"
      ]
    )

    # Functional pseudo-classes with arguments
    css_class(:nth_child_odd,
      background_color: [
        default: "white",
        ":nth-child(odd)": "#f0f0f0"
      ]
    )

    css_class(:nth_child_even,
      background_color: [
        default: "white",
        ":nth-child(even)": "#e0e0e0"
      ]
    )

    css_class(:nth_child_formula,
      background_color: [
        default: "white",
        ":nth-child(2n+1)": "#f0f0f0"
      ]
    )

    css_class(:nth_last_child,
      opacity: [
        default: "1",
        ":nth-last-child(2)": "0.8"
      ]
    )

    css_class(:nth_of_type,
      color: [
        default: "black",
        ":nth-of-type(3)": "red"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Link Pseudo-Classes
  # ============================================================================

  defmodule LinkPseudoClasses do
    use LiveStyle

    css_class(:link,
      color: [
        default: "blue",
        ":link": "blue",
        ":visited": "purple"
      ]
    )

    css_class(:any_link,
      text_decoration: [
        default: "none",
        ":any-link": "underline"
      ]
    )

    css_class(:target,
      background_color: [
        default: "transparent",
        ":target": "yellow"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Other Pseudo-Classes
  # ============================================================================

  defmodule OtherPseudoClasses do
    use LiveStyle

    css_class(:empty,
      display: [
        default: "block",
        ":empty": "none"
      ]
    )

    css_class(:autofill,
      background_color: [
        default: "white",
        ":autofill": "#e8f0fe"
      ]
    )

    css_class(:fullscreen,
      width: [
        default: "auto",
        ":fullscreen": "100vw"
      ]
    )

    css_class(:modal,
      z_index: [
        default: "auto",
        ":modal": "9999"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Functional Pseudo-Classes
  # ============================================================================

  defmodule FunctionalPseudoClasses do
    use LiveStyle

    # :not() pseudo-class
    css_class(:not_disabled,
      opacity: [
        default: "1",
        ":not(:disabled)": "1"
      ]
    )

    # :is() pseudo-class
    css_class(:is_hover_focus,
      color: [
        default: "black",
        ":is(:hover, :focus)": "blue"
      ]
    )

    # :where() pseudo-class
    css_class(:where_hover,
      color: [
        default: "black",
        ":where(:hover)": "blue"
      ]
    )

    # :has() pseudo-class
    css_class(:has_focus,
      border_color: [
        default: "gray",
        ":has(:focus)": "blue"
      ]
    )
  end

  # ============================================================================
  # Tests - Form State Pseudo-Classes
  # ============================================================================

  describe "form state pseudo-classes" do
    test ":disabled has priority offset 92" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.disabled"]

      disabled = rule.atomic_classes["color"].classes[":disabled"]
      assert disabled.ltr =~ ":disabled{color:gray}"
      # 3000 (color) + 92 (:disabled) = 3092
      assert disabled.priority == 3092
    end

    test ":enabled has priority offset 91" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.enabled"]

      enabled = rule.atomic_classes["opacity"].classes[":enabled"]
      # 3000 (opacity) + 91 (:enabled) = 3091
      assert enabled.priority == 3091
    end

    test ":checked has priority offset 101" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.checked"]

      checked = rule.atomic_classes["background-color"].classes[":checked"]
      # 3000 (background-color) + 101 (:checked) = 3101
      assert checked.priority == 3101
    end

    test ":valid has priority offset 103" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.valid"]

      valid = rule.atomic_classes["border-color"].classes[":valid"]
      # 2000 (border-color shorthand) + 103 (:valid) = 2103
      assert valid.priority == 2103
    end

    test ":invalid has priority offset 104" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.invalid"]

      invalid = rule.atomic_classes["border-color"].classes[":invalid"]
      # 2000 (border-color shorthand) + 104 (:invalid) = 2104
      assert invalid.priority == 2104
    end

    test ":required has priority offset 93" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.required"]

      required = rule.atomic_classes["border-style"].classes[":required"]
      # 2000 (border-style shorthand) + 93 (:required) = 2093
      assert required.priority == 2093
    end

    test ":placeholder-shown has priority offset 97" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.placeholder_shown"]

      ps = rule.atomic_classes["color"].classes[":placeholder-shown"]
      # 3000 (color) + 97 (:placeholder-shown) = 3097
      assert ps.priority == 3097
    end
  end

  # ============================================================================
  # Tests - Focus Variants
  # ============================================================================

  describe "focus variant pseudo-classes" do
    test ":focus-visible has priority offset 160" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FocusPseudoClasses.focus_visible"]

      fv = rule.atomic_classes["outline"].classes[":focus-visible"]
      assert fv.ltr =~ ":focus-visible{outline:2px solid blue}"
      # 2000 (outline shorthand) + 160 (:focus-visible) = 2160
      assert fv.priority == 2160
    end

    test ":focus-within has priority offset 140" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FocusPseudoClasses.focus_within"]

      fw = rule.atomic_classes["border-color"].classes[":focus-within"]
      # 2000 (border-color shorthand) + 140 (:focus-within) = 2140
      assert fw.priority == 2140
    end
  end

  # ============================================================================
  # Tests - Tree-Structural Pseudo-Classes
  # ============================================================================

  describe "tree-structural pseudo-classes" do
    test ":first-child has priority offset 52" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.first_child"]

      fc = rule.atomic_classes["margin-top"].classes[":first-child"]
      # 4000 (margin-top physical) + 52 (:first-child) = 4052
      assert fc.priority == 4052
    end

    test ":last-child has priority offset 54" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.last_child"]

      lc = rule.atomic_classes["margin-bottom"].classes[":last-child"]
      # 4000 (margin-bottom physical) + 54 (:last-child) = 4054
      assert lc.priority == 4054
    end

    test ":only-child has priority offset 56" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.only_child"]

      oc = rule.atomic_classes["margin"].classes[":only-child"]
      # 1000 (margin shorthand) + 56 (:only-child) = 1056
      assert oc.priority == 1056
    end

    test ":nth-child functional pseudo-class has priority offset 60" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.nth_child_odd"]

      nth = rule.atomic_classes["background-color"].classes[":nth-child(odd)"]
      # 3000 (background-color) + 60 (:nth-child) = 3060
      assert nth.priority == 3060
    end

    test ":nth-child with formula has priority offset 60" do
      manifest = get_manifest()

      rule =
        manifest.rules[
          "LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.nth_child_formula"
        ]

      nth = rule.atomic_classes["background-color"].classes[":nth-child(2n+1)"]
      # 3000 (background-color) + 60 (:nth-child) = 3060
      assert nth.priority == 3060
    end

    test ":nth-last-child has priority offset 61" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.nth_last_child"]

      nlc = rule.atomic_classes["opacity"].classes[":nth-last-child(2)"]
      # 3000 (opacity) + 61 (:nth-last-child) = 3061
      assert nlc.priority == 3061
    end
  end

  # ============================================================================
  # Tests - Link Pseudo-Classes
  # ============================================================================

  describe "link pseudo-classes" do
    test ":link has priority offset 80" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.LinkPseudoClasses.link"]

      link = rule.atomic_classes["color"].classes[":link"]
      # 3000 (color) + 80 (:link) = 3080
      assert link.priority == 3080
    end

    test ":visited has priority offset 85" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.LinkPseudoClasses.link"]

      visited = rule.atomic_classes["color"].classes[":visited"]
      # 3000 (color) + 85 (:visited) = 3085
      assert visited.priority == 3085
    end

    test ":target has priority offset 84" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.LinkPseudoClasses.target"]

      target = rule.atomic_classes["background-color"].classes[":target"]
      # 3000 (background-color) + 84 (:target) = 3084
      assert target.priority == 3084
    end
  end

  # ============================================================================
  # Tests - Other Pseudo-Classes
  # ============================================================================

  describe "other pseudo-classes" do
    test ":empty has priority offset 70" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.OtherPseudoClasses.empty"]

      empty = rule.atomic_classes["display"].classes[":empty"]
      # 3000 (display) + 70 (:empty) = 3070
      assert empty.priority == 3070
    end

    test ":autofill has priority offset 110" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.OtherPseudoClasses.autofill"]

      autofill = rule.atomic_classes["background-color"].classes[":autofill"]
      # 3000 (background-color) + 110 (:autofill) = 3110
      assert autofill.priority == 3110
    end

    test ":fullscreen has priority offset 122" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.OtherPseudoClasses.fullscreen"]

      fs = rule.atomic_classes["width"].classes[":fullscreen"]
      # 4000 (width physical) + 122 (:fullscreen) = 4122
      assert fs.priority == 4122
    end
  end

  # ============================================================================
  # Tests - Functional Pseudo-Classes
  # ============================================================================

  describe "functional pseudo-classes" do
    test ":not() has priority offset 40" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FunctionalPseudoClasses.not_disabled"]

      not_dis = rule.atomic_classes["opacity"].classes[":not(:disabled)"]
      # 3000 (opacity) + 40 (:not) = 3040
      assert not_dis.priority == 3040
    end

    test ":is() has priority offset 40" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FunctionalPseudoClasses.is_hover_focus"]

      is_hf = rule.atomic_classes["color"].classes[":is(:hover, :focus)"]
      # 3000 (color) + 40 (:is) = 3040
      assert is_hf.priority == 3040
    end

    test ":where() has priority offset 40" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FunctionalPseudoClasses.where_hover"]

      where_h = rule.atomic_classes["color"].classes[":where(:hover)"]
      # 3000 (color) + 40 (:where) = 3040
      assert where_h.priority == 3040
    end

    test ":has() has priority offset 45" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FunctionalPseudoClasses.has_focus"]

      has_f = rule.atomic_classes["border-color"].classes[":has(:focus)"]
      # 2000 (border-color shorthand) + 45 (:has) = 2045
      assert has_f.priority == 2045
    end
  end

  # ============================================================================
  # Tests - CSS Output Format
  # ============================================================================

  describe "css output format" do
    test "pseudo-class CSS is properly formatted" do
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PseudoClassesTest.FormStatePseudoClasses.disabled"]

      disabled = rule.atomic_classes["color"].classes[":disabled"]
      # Format should be: .{class}:disabled{property:value}
      assert disabled.ltr =~ ~r/^\.[a-z0-9]+:disabled\{color:gray\}$/
    end

    test "functional pseudo-class CSS preserves arguments" do
      manifest = get_manifest()

      rule =
        manifest.rules["LiveStyle.PseudoClassesTest.TreeStructuralPseudoClasses.nth_child_odd"]

      nth = rule.atomic_classes["background-color"].classes[":nth-child(odd)"]
      # Format should include the argument
      assert nth.ltr =~ ~r/:nth-child\(odd\)\{background-color:/
    end
  end
end
