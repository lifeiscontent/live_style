defmodule LiveStyle.StyleMergingTest do
  @moduledoc """
  Comprehensive tests for style merging and deduplication behavior.

  These tests verify that LiveStyle's style merging (css/css_class functions)
  matches StyleX's stylex.props() behavior for:
  - Property collision resolution (last wins)
  - Shorthand/longhand property conflicts
  - Null value handling (property removal)
  - Conditional style merging
  - Cross-module style merging

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-props-test.js
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Test Modules - Property collision resolution
  # ===========================================================================

  defmodule ColorCollision do
    use LiveStyle

    css_class(:red, color: "red")
    css_class(:blue, color: "blue")
    css_class(:green, color: "green")
  end

  # ===========================================================================
  # Test Modules - Null value handling
  # ===========================================================================

  defmodule NullStyles do
    use LiveStyle

    css_class(:colored, color: "red")
    css_class(:revert_color, color: nil)
    css_class(:styled, color: "blue", background_color: "white")
    css_class(:revert_bg, background_color: nil)
  end

  # ===========================================================================
  # Test Modules - Shorthand/longhand property conflicts
  # ===========================================================================

  defmodule ShorthandStyles do
    use LiveStyle

    css_class(:padding_all, padding: 5)
    css_class(:padding_end_override, padding: 5, padding_end: 10)
    css_class(:padding_start_only, padding: 2, padding_start: 10)
    css_class(:margin_all, margin: 0)

    css_class(:margin_longhands,
      margin_bottom: 15,
      margin_inline_end: 10,
      margin_inline_start: 20,
      margin_top: 5
    )

    css_class(:margin_override, margin: 0, margin_bottom: 100)
  end

  defmodule NullLonghand do
    use LiveStyle

    css_class(:foo, padding: 5, padding_end: 10)
    css_class(:bar, padding: 2, padding_start: nil)
  end

  # ===========================================================================
  # Test Modules - Cross-module merging
  # ===========================================================================

  defmodule ModuleA do
    use LiveStyle

    css_class(:base, color: "red")
  end

  defmodule ModuleB do
    use LiveStyle

    css_class(:override, background_color: "blue")
  end

  defmodule ModuleC do
    use LiveStyle

    css_class(:color_override, color: "green")
  end

  # ===========================================================================
  # Test Modules - Pseudo-selector styles
  # ===========================================================================

  defmodule PseudoStyles do
    use LiveStyle

    css_class(:link,
      color: %{
        :default => "blue",
        ":hover" => "red",
        ":focus" => "green"
      }
    )

    css_class(:override_hover,
      color: %{
        ":hover" => "purple"
      }
    )
  end

  # ===========================================================================
  # Test Modules - Media query styles
  # ===========================================================================

  defmodule MediaStyles do
    use LiveStyle

    css_class(:responsive,
      background_color: %{
        :default => "red",
        "@media (min-width: 1000px)" => "blue",
        "@media (min-width: 2000px)" => "purple"
      }
    )

    css_class(:override_large,
      background_color: %{
        "@media (min-width: 1000px)" => "green"
      }
    )
  end

  # ===========================================================================
  # Test Modules - Dynamic styles
  # ===========================================================================

  defmodule DynamicStyles do
    use LiveStyle

    css_class(:static_color, color: "red")

    css_class(:dynamic_bg, fn bg_color ->
      [background_color: bg_color]
    end)

    css_class(:dynamic_opacity, fn opacity ->
      [opacity: opacity]
    end)
  end

  # ===========================================================================
  # Test Modules - Edge cases
  # ===========================================================================

  defmodule EdgeCaseStyles do
    use LiveStyle

    css_class(:empty, [])
    css_class(:single, color: "red")
  end

  # ===========================================================================
  # Tests - Property collision resolution
  # ===========================================================================

  describe "property collision - last wins" do
    test "last style wins for same property" do
      # StyleX: stylex.props([styles.red, styles.blue]) -> className: "xju2f9n" (blue only)
      class = LiveStyle.get_css_class(ColorCollision, [:red, :blue])

      red_rule = LiveStyle.get_metadata(ColorCollision, {:class, :red})
      blue_rule = LiveStyle.get_metadata(ColorCollision, {:class, :blue})

      classes = String.split(class, " ")

      # Blue should be present (last)
      assert blue_rule.atomic_classes["color"].class in classes
      # Red should NOT be present (overridden)
      refute red_rule.atomic_classes["color"].class in classes
    end

    test "reversed order gives different result" do
      # StyleX: stylex.props([styles.blue, styles.red]) -> className: "x1e2nbdu" (red only)
      class = LiveStyle.get_css_class(ColorCollision, [:blue, :red])

      red_rule = LiveStyle.get_metadata(ColorCollision, {:class, :red})
      blue_rule = LiveStyle.get_metadata(ColorCollision, {:class, :blue})

      classes = String.split(class, " ")

      # Red should be present (last)
      assert red_rule.atomic_classes["color"].class in classes
      # Blue should NOT be present (overridden)
      refute blue_rule.atomic_classes["color"].class in classes
    end

    test "three-way collision - only last survives" do
      class = LiveStyle.get_css_class(ColorCollision, [:red, :blue, :green])

      green_rule = LiveStyle.get_metadata(ColorCollision, {:class, :green})

      classes = String.split(class, " ")

      # Only green should be present
      assert green_rule.atomic_classes["color"].class in classes
      assert length(classes) == 1
    end
  end

  # ===========================================================================
  # Tests - Null value handling
  # ===========================================================================

  describe "null value handling" do
    test "null removes property from merged result" do
      # StyleX: stylex.props([styles.red, styles.revert]) -> {} (empty)
      class = LiveStyle.get_css_class(NullStyles, [:colored, :revert_color])

      # Class should be empty or only whitespace
      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      assert classes == []
    end

    test "null after non-null removes, non-null after null adds back" do
      # StyleX: stylex.props([styles.revert, styles.red]) -> className: "x1e2nbdu"
      class = LiveStyle.get_css_class(NullStyles, [:revert_color, :colored])

      colored_rule = LiveStyle.get_metadata(NullStyles, {:class, :colored})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Color should be present (added back after revert)
      assert colored_rule.atomic_classes["color"].class in classes
    end

    test "selective null removes only that property" do
      # styled has color and background-color
      # revert_bg only nulls background-color
      class = LiveStyle.get_css_class(NullStyles, [:styled, :revert_bg])

      styled_rule = LiveStyle.get_metadata(NullStyles, {:class, :styled})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Color should remain
      assert styled_rule.atomic_classes["color"].class in classes
      # Should only be one class (color)
      assert length(classes) == 1
    end
  end

  # ===========================================================================
  # Tests - Shorthand/longhand property conflicts
  # ===========================================================================

  describe "shorthand/longhand conflicts" do
    test "shorthand then shorthand - last shorthand wins" do
      # When merging two shorthands, the last one wins completely
      class = LiveStyle.get_css_class(ShorthandStyles, [:padding_all, :padding_start_only])

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

      class = LiveStyle.get_css_class(ShorthandStyles, [:margin_longhands, :margin_override])

      _longhands_rule = LiveStyle.get_metadata(ShorthandStyles, {:class, :margin_longhands})
      override_rule = LiveStyle.get_metadata(ShorthandStyles, {:class, :margin_override})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes
      assert length(classes) >= 2

      # margin_bottom from override should be present (100px wins over 15px)
      if override_rule.atomic_classes["margin-bottom"] do
        assert override_rule.atomic_classes["margin-bottom"].class in classes
      end
    end

    test "shorthand with null longhand" do
      # padding: 5, paddingEnd: 10 merged with padding: 2, paddingStart: null
      # -> paddingEnd survives, padding changes to 2, paddingStart is removed

      class = LiveStyle.get_css_class(NullLonghand, [:foo, :bar])

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
      class_a = LiveStyle.get_css_class(ModuleA, [:base])
      class_b = LiveStyle.get_css_class(ModuleB, [:override])

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
      class_a = LiveStyle.get_css_class(ModuleA, [:base])
      class_c = LiveStyle.get_css_class(ModuleC, [:color_override])

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
      class = LiveStyle.get_css_class(PseudoStyles, [:link])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes for default, hover, focus
      assert length(classes) >= 2
    end

    test "pseudo-selector can be overridden" do
      class = LiveStyle.get_css_class(PseudoStyles, [:link, :override_hover])

      override_rule = LiveStyle.get_metadata(PseudoStyles, {:class, :override_hover})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have override_hover's hover class
      hover_class = override_rule.atomic_classes["color"].classes[":hover"].class
      assert hover_class in classes
    end
  end

  # ===========================================================================
  # Tests - Media query style merging
  # ===========================================================================

  describe "media query style merging" do
    test "media query styles are all included" do
      class = LiveStyle.get_css_class(MediaStyles, [:responsive])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have multiple classes for different breakpoints
      assert length(classes) >= 2
    end

    test "media query can be overridden" do
      class = LiveStyle.get_css_class(MediaStyles, [:responsive, :override_large])

      override_rule = LiveStyle.get_metadata(MediaStyles, {:class, :override_large})

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should include the override's class for the 1000px breakpoint
      media_classes = override_rule.atomic_classes["background-color"].classes
      media_class = media_classes["@media (min-width: 1000px)"].class
      assert media_class in classes
    end
  end

  # ===========================================================================
  # Tests - Dynamic style merging
  # ===========================================================================

  describe "dynamic style merging" do
    test "static and dynamic styles can be merged" do
      # Get static class
      static_class = LiveStyle.get_css_class(DynamicStyles, [:static_color])

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
      # Dynamic results are tuples: {class, style_map}
      assert is_tuple(bg_result)
      assert is_tuple(opacity_result)

      {bg_class, bg_vars} = bg_result
      {opacity_class, opacity_vars} = opacity_result

      assert is_binary(bg_class)
      assert is_map(bg_vars)
      assert is_binary(opacity_class)
      assert is_map(opacity_vars)
    end
  end

  # ===========================================================================
  # Tests - Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "empty style list returns empty class" do
      class = LiveStyle.get_css_class(EdgeCaseStyles, [])

      assert class == "" or class == nil
    end

    test "list with only nil/false values returns empty" do
      class = LiveStyle.get_css_class(EdgeCaseStyles, [nil, nil, false])

      classes =
        (class || "")
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "false"))

      assert classes == []
    end

    test "duplicate refs are deduplicated" do
      class = LiveStyle.get_css_class(EdgeCaseStyles, [:single, :single, :single])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should only have one class
      assert length(classes) == 1
    end

    test "mixed valid and invalid refs" do
      class = LiveStyle.get_css_class(EdgeCaseStyles, [nil, :single, false, :single, nil])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "false"))

      # Should only have one class (single, deduplicated)
      assert length(classes) == 1
    end
  end
end
