defmodule LiveStyle.PropsTest do
  @moduledoc """
  Tests for style merging (css/css_class functions).

  These tests mirror StyleX's transform-stylex-props-test.js to ensure
  LiveStyle merges styles the same way StyleX does with stylex.props().
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Basic Style Application
  # ============================================================================

  defmodule BasicStyles do
    use LiveStyle

    css_class(:red, color: "red")
    css_class(:blue, color: "blue")
    css_class(:bold, font_weight: "bold")
    css_class(:large, font_size: "24px")
  end

  defmodule ConflictingStyles do
    use LiveStyle

    css_class(:primary, color: "blue", background_color: "white")
    css_class(:secondary, color: "red")
    css_class(:warning, color: "orange", background_color: "yellow")
  end

  # ============================================================================
  # Style Merging
  # ============================================================================

  describe "basic style application" do
    test "css/2 returns Attrs struct with class" do
      attrs = LiveStyle.get_css(BasicStyles, [:red])

      assert %LiveStyle.Attrs{class: class} = attrs
      assert is_binary(class)
      assert class =~ ~r/^[a-z0-9]+$/
    end

    test "css_class/2 returns class string" do
      class = LiveStyle.get_css_class(BasicStyles, [:red])

      assert is_binary(class)
      assert class =~ ~r/^[a-z0-9]+$/
    end

    test "applying single style returns correct class with correct metadata" do
      # StyleX: { color: "x1e2nbdu" } -> metadata: [x1e2nbdu, {ltr: ".x1e2nbdu{color:red}", rtl: null}, 3000]
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.PropsTest.BasicStyles.red"]

      # Check the atomic_class metadata
      color = rule.atomic_classes["color"]
      assert color.ltr =~ ~r/\.x[a-z0-9]+\{color:red\}$/
      assert color.rtl == nil
      assert color.priority == 3000

      # The class returned by css_class should match the metadata
      class = LiveStyle.get_css_class(BasicStyles, [:red])
      assert class == color.class
    end
  end

  describe "style merging" do
    test "multiple non-conflicting styles are combined" do
      # StyleX: stylex.props(styles.red, styles.bold) combines both
      class = LiveStyle.get_css_class(BasicStyles, [:red, :bold])

      # Should have classes for both properties
      classes = String.split(class, " ")
      assert length(classes) == 2
    end

    test "later styles override earlier styles for same property" do
      # StyleX: stylex.props(styles.primary, styles.secondary)
      # -> only secondary's color is applied (later wins)
      manifest = get_manifest()
      primary_rule = manifest.rules["LiveStyle.PropsTest.ConflictingStyles.primary"]
      secondary_rule = manifest.rules["LiveStyle.PropsTest.ConflictingStyles.secondary"]

      class = LiveStyle.get_css_class(ConflictingStyles, [:primary, :secondary])
      classes = String.split(class, " ")

      # Should have secondary's color class (red) and primary's background class
      primary_bg_class = primary_rule.atomic_classes["background-color"].class
      secondary_color_class = secondary_rule.atomic_classes["color"].class

      assert secondary_color_class in classes
      assert primary_bg_class in classes

      # Should NOT have primary's color class (blue) - it was overridden
      primary_color_class = primary_rule.atomic_classes["color"].class
      refute primary_color_class in classes
    end

    test "multiple style overrides - last wins" do
      # StyleX: stylex.props(styles.primary, styles.secondary, styles.warning)
      manifest = get_manifest()
      warning_rule = manifest.rules["LiveStyle.PropsTest.ConflictingStyles.warning"]

      class = LiveStyle.get_css_class(ConflictingStyles, [:primary, :secondary, :warning])
      classes = String.split(class, " ")

      # Color should be warning's orange (last)
      warning_color_class = warning_rule.atomic_classes["color"].class
      assert warning_color_class in classes

      # Background should be warning's yellow (last)
      warning_bg_class = warning_rule.atomic_classes["background-color"].class
      assert warning_bg_class in classes
    end

    test "nil values are filtered out" do
      # StyleX: stylex.props(styles.red, null, styles.bold)
      # -> null is ignored
      class = LiveStyle.get_css_class(BasicStyles, [:red, nil, :bold])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      assert length(classes) == 2
    end

    test "empty refs list returns empty class" do
      class = LiveStyle.get_css_class(BasicStyles, [])

      assert class == "" or class == nil
    end
  end

  describe "class deduplication" do
    test "same style applied multiple times is not duplicated" do
      class = LiveStyle.get_css_class(BasicStyles, [:red, :red, :red])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should only have one class, not three
      assert length(classes) == 1
    end

    test "same property from different rules - only last class appears" do
      class = LiveStyle.get_css_class(ConflictingStyles, [:primary, :secondary])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == ""))

      # Should have 2 classes: one for background-color (from primary)
      # and one for color (from secondary, overriding primary's color)
      assert length(classes) == 2
    end
  end

  describe "attrs struct" do
    test "Attrs struct can be used with Phoenix.HTML" do
      attrs = LiveStyle.get_css(BasicStyles, [:red])

      assert %LiveStyle.Attrs{} = attrs
      assert Map.has_key?(attrs, :class)
    end

    test "Attrs can include style for inline styles" do
      # When dynamic values are used, style attribute may be needed
      attrs = LiveStyle.get_css(BasicStyles, [:red])

      # For static styles, style should be nil or empty
      assert attrs.style == nil or attrs.style == %{}
    end
  end

  describe "conditional styles" do
    test "false condition excludes style" do
      # Pattern: css(module, [condition && :style])
      class = LiveStyle.get_css_class(BasicStyles, [false && :red, :bold])

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

      class = LiveStyle.get_css_class(BasicStyles, [include_red && :red, :bold])

      classes =
        class
        |> String.split(" ")
        |> Enum.reject(&(&1 == "" or &1 == "true"))

      # Should have both classes
      assert length(classes) == 2
    end
  end
end
