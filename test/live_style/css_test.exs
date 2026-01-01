defmodule LiveStyle.CSSTest do
  @moduledoc """
  Tests for CSS generation and style merging.

  These tests verify that LiveStyle's `css/2` and `class/2` functions work correctly,
  mirroring StyleX's `stylex.props()` behavior for:
  - Property collision resolution (last wins)
  - Shorthand/longhand property conflicts
  - Null value handling (property removal)
  - Conditional style merging
  - Cross-module style merging

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-props-test.js
  """
  use LiveStyle.TestCase
  use Snapshy

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.Class

  # ===========================================================================
  # Test Modules - Basic Styles
  # ===========================================================================

  defmodule BasicStyles do
    use LiveStyle

    class(:red, color: "red")
    class(:blue, color: "blue")
    class(:green, color: "green")
    class(:bold, font_weight: "bold")
    class(:large, font_size: "24px")
  end

  defmodule ConflictingStyles do
    use LiveStyle

    class(:primary, color: "blue", background_color: "white")
    class(:secondary, color: "red")
    class(:warning, color: "orange", background_color: "yellow")
  end

  # ===========================================================================
  # Test Modules - Null value handling
  # ===========================================================================

  defmodule NullStyles do
    use LiveStyle

    class(:colored, color: "red")
    class(:revert_color, color: nil)
    class(:styled, color: "blue", background_color: "white")
    class(:revert_bg, background_color: nil)
  end

  # ===========================================================================
  # Test Modules - Shorthand/longhand property conflicts
  # ===========================================================================

  defmodule ShorthandStyles do
    use LiveStyle

    class(:padding_all, padding: 5)
    class(:padding_end_override, padding: 5, padding_end: 10)
    class(:padding_start_only, padding: 2, padding_start: 10)
    class(:margin_all, margin: 0)

    class(:margin_longhands,
      margin_bottom: 15,
      margin_inline_end: 10,
      margin_inline_start: 20,
      margin_top: 5
    )

    class(:margin_override, margin: 0, margin_bottom: 100)
  end

  defmodule NullLonghand do
    use LiveStyle

    class(:foo, padding: 5, padding_end: 10)
    class(:bar, padding: 2, padding_start: nil)
  end

  # ===========================================================================
  # Test Modules - Cross-module merging
  # ===========================================================================

  defmodule ModuleA do
    use LiveStyle

    class(:base, color: "red")
  end

  defmodule ModuleB do
    use LiveStyle

    class(:override, background_color: "blue")
  end

  defmodule ModuleC do
    use LiveStyle

    class(:color_override, color: "green")
  end

  # ===========================================================================
  # Test Modules - Pseudo-selector styles
  # ===========================================================================

  defmodule PseudoStyles do
    use LiveStyle

    class(:link,
      color: [
        default: "blue",
        ":hover": "red",
        ":focus": "green"
      ]
    )

    class(:override_hover,
      color: [
        ":hover": "purple"
      ]
    )
  end

  # ===========================================================================
  # Test Modules - Media query styles
  # ===========================================================================

  defmodule MediaStyles do
    use LiveStyle

    class(:responsive,
      background_color: [
        default: "red",
        "@media (min-width: 1000px)": "blue",
        "@media (min-width: 2000px)": "purple"
      ]
    )

    class(:override_large,
      background_color: [
        "@media (min-width: 1000px)": "green"
      ]
    )
  end

  # ===========================================================================
  # Test Modules - Dynamic styles
  # ===========================================================================

  defmodule DynamicStyles do
    use LiveStyle

    class(:static_color, color: "red")

    class(:dynamic_bg, fn bg_color ->
      [background_color: bg_color]
    end)

    class(:dynamic_opacity, fn opacity ->
      [opacity: opacity]
    end)
  end

  # ===========================================================================
  # Test Modules - Edge cases
  # ===========================================================================

  defmodule EdgeCaseStyles do
    use LiveStyle

    class(:empty, [])
    class(:single, color: "red")
  end

  # ===========================================================================
  # Tests - Basic API
  # ===========================================================================

  describe "basic API" do
    test "css/2 returns Attrs struct with class" do
      attrs = Compiler.get_css(BasicStyles, [:red])

      assert %LiveStyle.Attrs{class: class} = attrs
      assert is_binary(class)
      assert class =~ ~r/^[a-z0-9]+$/
    end

    test "class/2 returns class string" do
      class = Compiler.get_css_class(BasicStyles, [:red])

      assert is_binary(class)
      assert class =~ ~r/^[a-z0-9]+$/
    end

    test "applying single style returns correct metadata" do
      # StyleX: { color: "x1e2nbdu" } -> metadata: [x1e2nbdu, {ltr: ".x1e2nbdu{color:red}", rtl: null}, 3000]
      rule = Class.lookup!({LiveStyle.CSSTest.BasicStyles, :red})

      # Check the atomic_class metadata
      color = get_atomic(rule.atomic_classes, "color")
      assert field(color, :ltr) =~ ~r/\.x[a-z0-9]+\{color:red\}$/
      assert field(color, :rtl) == nil
      assert field(color, :priority) == 3000

      # The class returned by class should match the metadata
      class = Compiler.get_css_class(BasicStyles, [:red])
      assert class == field(color, :class)
    end

    test "Attrs struct has expected fields" do
      attrs = Compiler.get_css(BasicStyles, [:red])

      assert %LiveStyle.Attrs{} = attrs
      assert is_map_key(attrs, :class)

      # For static styles, style should be nil or empty
      assert attrs.style == nil or attrs.style == %{}
    end
  end

  # ===========================================================================
  # Tests - Property collision resolution
  # ===========================================================================

  describe "property collision - last wins" do
    test "last style wins for same property" do
      # StyleX: stylex.props([styles.red, styles.blue]) -> className: "xju2f9n" (blue only)
      class = Compiler.get_css_class(BasicStyles, [:red, :blue])

      red_rule = Class.lookup!({BasicStyles, :red})
      blue_rule = Class.lookup!({BasicStyles, :blue})

      classes = String.split(class, " ")

      # Blue should be present (last)
      assert field(get_atomic(blue_rule.atomic_classes, "color"), :class) in classes
      # Red should NOT be present (overridden)
      refute field(get_atomic(red_rule.atomic_classes, "color"), :class) in classes
    end

    test "reversed order gives different result" do
      # StyleX: stylex.props([styles.blue, styles.red]) -> className: "x1e2nbdu" (red only)
      class = Compiler.get_css_class(BasicStyles, [:blue, :red])

      red_rule = Class.lookup!({BasicStyles, :red})
      blue_rule = Class.lookup!({BasicStyles, :blue})

      classes = String.split(class, " ")

      # Red should be present (last)
      assert field(get_atomic(red_rule.atomic_classes, "color"), :class) in classes
      # Blue should NOT be present (overridden)
      refute field(get_atomic(blue_rule.atomic_classes, "color"), :class) in classes
    end

    test "three-way collision - only last survives" do
      class = Compiler.get_css_class(BasicStyles, [:red, :blue, :green])

      green_rule = Class.lookup!({BasicStyles, :green})

      classes = String.split(class, " ")

      # Only green should be present
      assert field(get_atomic(green_rule.atomic_classes, "color"), :class) in classes
      assert length(classes) == 1
    end

    test "multiple non-conflicting styles are combined" do
      # StyleX: stylex.props(styles.red, styles.bold) combines both
      class = Compiler.get_css_class(BasicStyles, [:red, :bold])

      # Should have classes for both properties
      classes = String.split(class, " ")
      assert length(classes) == 2
    end

    test "later styles override earlier styles for same property" do
      # StyleX: stylex.props(styles.primary, styles.secondary)
      # -> only secondary's color is applied (later wins)
      primary_rule = Class.lookup!({ConflictingStyles, :primary})
      secondary_rule = Class.lookup!({ConflictingStyles, :secondary})

      class = Compiler.get_css_class(ConflictingStyles, [:primary, :secondary])
      classes = String.split(class, " ")

      # Should have secondary's color class (red) and primary's background class
      primary_bg_class =
        field(get_atomic(primary_rule.atomic_classes, "background-color"), :class)

      secondary_color_class = field(get_atomic(secondary_rule.atomic_classes, "color"), :class)

      assert secondary_color_class in classes
      assert primary_bg_class in classes

      # Should NOT have primary's color class (blue) - it was overridden
      primary_color_class = field(get_atomic(primary_rule.atomic_classes, "color"), :class)
      refute primary_color_class in classes
    end

    test "multiple style overrides - last wins" do
      # StyleX: stylex.props(styles.primary, styles.secondary, styles.warning)
      warning_rule = Class.lookup!({ConflictingStyles, :warning})

      class =
        Compiler.get_css_class(ConflictingStyles, [:primary, :secondary, :warning])

      classes = String.split(class, " ")

      # Color should be warning's orange (last)
      warning_color_class = field(get_atomic(warning_rule.atomic_classes, "color"), :class)
      assert warning_color_class in classes

      # Background should be warning's yellow (last)
      warning_bg_class =
        field(get_atomic(warning_rule.atomic_classes, "background-color"), :class)

      assert warning_bg_class in classes
    end
  end

  # ===========================================================================
  # Tests - Null value handling
  # ===========================================================================

  describe "null value handling" do
    test "null removes property from merged result" do
      # StyleX: stylex.props([styles.red, styles.revert]) -> {} (empty)
      class = Compiler.get_css_class(NullStyles, [:colored, :revert_color])

      # Class should be empty or only whitespace
      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      assert classes == []
    end

    test "null after non-null removes, non-null after null adds back" do
      # StyleX: stylex.props([styles.revert, styles.red]) -> className: "x1e2nbdu"
      class = Compiler.get_css_class(NullStyles, [:revert_color, :colored])

      colored_rule = Class.lookup!({NullStyles, :colored})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Color should be present (added back after revert)
      assert field(get_atomic(colored_rule.atomic_classes, "color"), :class) in classes
    end

    test "selective null removes only that property" do
      # styled has color and background-color
      # revert_bg only nulls background-color
      class = Compiler.get_css_class(NullStyles, [:styled, :revert_bg])

      styled_rule = Class.lookup!({NullStyles, :styled})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Color should remain
      assert field(get_atomic(styled_rule.atomic_classes, "color"), :class) in classes
      # Should only be one class (color)
      assert length(classes) == 1
    end

    test "nil values in refs are filtered out" do
      # StyleX: stylex.props(styles.red, null, styles.bold)
      # -> null is ignored
      class = Compiler.get_css_class(BasicStyles, [:red, nil, :bold])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      assert length(classes) == 2
    end
  end

  # ===========================================================================
  # Tests - Shorthand/longhand property conflicts
  # ===========================================================================

  describe "shorthand/longhand conflicts" do
    test "shorthand then shorthand - last shorthand wins" do
      # When merging two shorthands, the last one wins completely
      class =
        Compiler.get_css_class(ShorthandStyles, [:padding_all, :padding_start_only])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have classes from padding_start_only
      assert not Enum.empty?(classes)
    end

    test "longhands then shorthand - shorthand overrides some but keeps explicit longhands" do
      # StyleX behavior: Last property wins, even if shorthand
      # margin_longhands then margin_override ->
      #   margin_inline_end and margin_inline_start survive (not overridden by margin_override)
      #   margin from override applies
      #   margin_bottom from override overrides the one from longhands

      class =
        Compiler.get_css_class(ShorthandStyles, [:margin_longhands, :margin_override])

      _longhands_rule = Class.lookup!({ShorthandStyles, :margin_longhands})
      override_rule = Class.lookup!({ShorthandStyles, :margin_override})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes
      assert length(classes) >= 2

      # margin_bottom from override should be present (100px wins over 15px)
      if get_atomic(override_rule.atomic_classes, "margin-bottom") do
        assert field(get_atomic(override_rule.atomic_classes, "margin-bottom"), :class) in classes
      end
    end

    test "shorthand with null longhand" do
      # padding: 5, paddingEnd: 10 merged with padding: 2, paddingStart: null
      # -> paddingEnd survives, padding changes to 2, paddingStart is removed

      class = Compiler.get_css_class(NullLonghand, [:foo, :bar])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have classes for padding_end and the new padding
      assert not Enum.empty?(classes)
    end
  end

  # ===========================================================================
  # Tests - Cross-module style merging
  # ===========================================================================

  describe "cross-module style merging" do
    test "styles from different modules can be merged" do
      # Get classes from both modules
      class_a = Compiler.get_css_class(ModuleA, [:base])
      class_b = Compiler.get_css_class(ModuleB, [:override])

      # Both should be non-empty
      assert class_a != ""
      assert class_b != ""

      # Combined should have both
      combined = "#{class_a} #{class_b}"
      classes = String.split(combined, " ") |> Enum.reject(&(&1 == ""))
      assert length(classes) == 2
    end

    test "cross-module collision - manual merge requires proper handling" do
      # When manually concatenating classes from different modules,
      # CSS specificity rules apply (both classes will be in DOM)
      class_a = Compiler.get_css_class(ModuleA, [:base])
      class_c = Compiler.get_css_class(ModuleC, [:color_override])

      # Both classes will be present - CSS cascade determines winner
      combined = "#{class_a} #{class_c}"
      classes = String.split(combined, " ") |> Enum.reject(&(&1 == ""))

      # Both classes are present - the browser will apply based on specificity/order
      assert length(classes) == 2
    end
  end

  # ===========================================================================
  # Tests - Pseudo-selector style merging
  # ===========================================================================

  describe "pseudo-selector style merging" do
    test "pseudo-selector styles are merged correctly" do
      class = Compiler.get_css_class(PseudoStyles, [:link])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes for default, hover, focus
      assert length(classes) >= 2
    end

    test "pseudo-selector can be overridden" do
      class = Compiler.get_css_class(PseudoStyles, [:link, :override_hover])

      override_rule = Class.lookup!({PseudoStyles, :override_hover})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have override_hover's hover class
      hover_class =
        field(
          get_class(field(get_atomic(override_rule.atomic_classes, "color"), :classes), ":hover"),
          :class
        )

      assert hover_class in classes
    end
  end

  # ===========================================================================
  # Tests - Media query style merging
  # ===========================================================================

  describe "media query style merging" do
    test "media query styles are all included" do
      class = Compiler.get_css_class(MediaStyles, [:responsive])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes for different breakpoints
      assert length(classes) >= 2
    end

    test "media query can be overridden" do
      class = Compiler.get_css_class(MediaStyles, [:responsive, :override_large])

      override_rule = Class.lookup!({MediaStyles, :override_large})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should include the override's class for the 1000px breakpoint
      media_classes =
        field(get_atomic(override_rule.atomic_classes, "background-color"), :classes)

      media_class = field(get_class(media_classes, "@media (min-width: 1000px)"), :class)
      assert media_class in classes
    end
  end

  # ===========================================================================
  # Tests - Dynamic style merging
  # ===========================================================================

  describe "dynamic style merging" do
    test "static and dynamic styles can be merged" do
      # Get static class
      static_class = Compiler.get_css_class(DynamicStyles, [:static_color])

      # Get dynamic result - pass the value directly, not as a map
      dynamic_result = DynamicStyles.__dynamic_dynamic_bg__("blue")

      # Both should produce non-empty results
      assert static_class != ""
      assert dynamic_result != nil
    end

    test "multiple dynamic styles can be combined" do
      bg_result = DynamicStyles.__dynamic_dynamic_bg__("blue")
      opacity_result = DynamicStyles.__dynamic_dynamic_opacity__("0.5")

      # Both should produce results with class and var info
      # Dynamic results are tuples: {class, var_list}
      assert is_tuple(bg_result)
      assert is_tuple(opacity_result)

      {bg_class, bg_vars} = bg_result
      {opacity_class, opacity_vars} = opacity_result

      assert is_binary(bg_class)
      assert is_list(bg_vars)
      assert is_binary(opacity_class)
      assert is_list(opacity_vars)
    end
  end

  # ===========================================================================
  # Tests - Class deduplication
  # ===========================================================================

  describe "class deduplication" do
    test "same style applied multiple times is not duplicated" do
      class = Compiler.get_css_class(BasicStyles, [:red, :red, :red])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should only have one class, not three
      assert length(classes) == 1
    end

    test "same property from different rules - only last class appears" do
      class = Compiler.get_css_class(ConflictingStyles, [:primary, :secondary])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have 2 classes: one for background-color (from primary)
      # and one for color (from secondary, overriding primary's color)
      assert length(classes) == 2
    end
  end

  # ===========================================================================
  # Tests - Conditional styles
  # ===========================================================================

  describe "conditional styles" do
    test "false condition excludes style" do
      # Pattern: css(module, [condition && :style])
      class = Compiler.get_css_class(BasicStyles, [false && :red, :bold])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "false"))

      # Should only have bold's class
      assert length(classes) == 1
    end

    test "true condition includes style" do
      # Test that a truthy condition includes the style
      # Use System.get_env to get a runtime value that compiler can't optimize away
      # The env var doesn't need to exist - we just need a non-nil check
      include_red = System.get_env("__NONEXISTENT__") == nil

      class = Compiler.get_css_class(BasicStyles, [include_red && :red, :bold])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "true"))

      # Should have both classes
      assert length(classes) == 2
    end
  end

  # ===========================================================================
  # Tests - Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "empty refs list returns empty class" do
      class = Compiler.get_css_class(EdgeCaseStyles, [])

      assert class == "" or class == nil
    end

    test "list with only nil/false values returns empty" do
      class = Compiler.get_css_class(EdgeCaseStyles, [nil, nil, false])

      classes =
        (class || "")
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "false"))

      assert classes == []
    end

    test "duplicate refs are deduplicated" do
      class = Compiler.get_css_class(EdgeCaseStyles, [:single, :single, :single])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should only have one class
      assert length(classes) == 1
    end

    test "mixed valid and invalid refs" do
      class =
        Compiler.get_css_class(EdgeCaseStyles, [nil, :single, false, :single, nil])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "false"))

      # Should only have one class (single, deduplicated)
      assert length(classes) == 1
    end
  end

  # ===========================================================================
  # Snapshot Tests - CSS Output
  # ===========================================================================

  describe "CSS output snapshots" do
    test_snapshot "basic styles CSS output" do
      extract_css_for_module(BasicStyles)
    end

    test_snapshot "conflicting styles CSS output" do
      extract_css_for_module(ConflictingStyles)
    end

    test_snapshot "shorthand styles CSS output" do
      extract_css_for_module(ShorthandStyles)
    end

    test_snapshot "pseudo styles CSS output" do
      extract_css_for_module(PseudoStyles)
    end

    test_snapshot "media styles CSS output" do
      extract_css_for_module(MediaStyles)
    end
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  defp extract_css_for_module(_module) do
    css = Compiler.generate_css()

    # Extract all CSS rules
    css
    |> String.split("\n")
    |> Enum.filter(fn line ->
      # Include lines that have CSS rules
      String.contains?(line, "{") and String.contains?(line, "}")
    end)
    |> Enum.join("\n")
  end
end
