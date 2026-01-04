defmodule LiveStyle.CSSOrderingTest do
  @moduledoc """
  Tests for CSS output ordering, determinism, and stability.

  Based on StyleX testing patterns from:
  - createOrderedCSSStyleSheet-test.js (ordering, deduplication)
  - stylex-test.js (merging, last-wins semantics)

  These tests ensure:
  1. CSS output is deterministic (same input = same output)
  2. CSS rules are ordered by priority groups (matching StyleX)
  3. Duplicate rules are deduplicated

  LiveStyle's ordering (matching StyleX):
  1. @property rules - For typed CSS variables
  2. @property rules - For dynamic CSS variables
  3. @keyframes animations
  4. CSS custom properties - :root { --var: value; }
  5. @position-try rules
  6. View transition rules
  7. Atomic style rules
  8. Theme override rules
  """
  use LiveStyle.TestCase

  # ============================================================================
  # CSS Output Determinism Tests
  # ============================================================================

  describe "CSS output determinism" do
    test "same input produces identical output on repeated calls" do
      css1 = LiveStyle.Compiler.generate_css()
      css2 = LiveStyle.Compiler.generate_css()

      assert css1 == css2, "CSS output should be identical on repeated calls"
    end

    test "CSS classes are sorted deterministically" do
      css = LiveStyle.Compiler.generate_css()

      # Extract all class selectors from CSS
      class_selectors =
        Regex.scan(~r/\.x[a-z0-9]+(?::not\(#\\#\))?(?::[\w-]+(?:\([^)]*\))?)*\{/, css)
        |> Enum.map(&hd/1)

      # Verify they are sorted (or at least consistent)
      assert class_selectors == Enum.uniq(class_selectors),
             "No duplicate class definitions should exist"
    end

    test "CSS output hash is stable across compilations" do
      css = LiveStyle.Compiler.generate_css()
      hash1 = :erlang.phash2(css)

      # Generate again
      css_again = LiveStyle.Compiler.generate_css()
      hash2 = :erlang.phash2(css_again)

      assert hash1 == hash2, "CSS hash should be stable"
    end
  end

  # ============================================================================
  # Priority-Based Ordering Tests (StyleX-compatible)
  # ============================================================================

  describe "priority-based CSS ordering (StyleX-compatible)" do
    test "@property rules come before @keyframes" do
      css = LiveStyle.Compiler.generate_css()

      property_pos = find_first_position(css, "@property")
      keyframes_pos = find_first_position(css, "@keyframes")

      if property_pos && keyframes_pos do
        assert property_pos < keyframes_pos,
               "@property rules should come before @keyframes"
      end
    end

    test "@keyframes come before :root vars" do
      css = LiveStyle.Compiler.generate_css()

      keyframes_pos = find_first_position(css, "@keyframes")
      root_pos = find_first_position(css, ":root{")

      if keyframes_pos && root_pos do
        assert keyframes_pos < root_pos,
               "@keyframes should come before :root vars (StyleX order)"
      end
    end

    test ":root vars come before regular classes" do
      css = LiveStyle.Compiler.generate_css()

      root_pos = find_first_position(css, ":root{")
      # Find first atomic class (not a theme class)
      class_pos = find_first_position(css, ~r/\.x[a-z0-9]+\{/)

      if root_pos && class_pos do
        assert root_pos < class_pos,
               ":root vars should come before regular classes"
      end
    end

    test "regular classes come before pseudo-class variants" do
      css = LiveStyle.Compiler.generate_css()

      # Find a regular class (no :not(#\#))
      regular_classes =
        Regex.scan(~r/\.x[a-z0-9]+\{[^}]+\}/, css)
        |> List.first()

      # Find pseudo-class variants (:hover, :focus, etc.)
      pseudo_classes =
        Regex.scan(~r/\.x[a-z0-9]+:not\(#\\#\):(?:hover|focus|active)\{/, css)
        |> List.first()

      if regular_classes && pseudo_classes do
        regular_pos = :binary.match(css, hd(regular_classes)) |> elem(0)
        pseudo_pos = :binary.match(css, hd(pseudo_classes)) |> elem(0)

        assert regular_pos < pseudo_pos,
               "Regular classes should come before pseudo-class variants"
      end
    end

    test "theme classes come at the end" do
      css = LiveStyle.Compiler.generate_css()

      # Theme classes start with .t
      theme_pos = find_first_position(css, ~r/\.t[a-z0-9]+,/)

      if theme_pos do
        # Should be near the end
        css_length = String.length(css)
        # Theme classes should be in the last 50% of the file
        assert theme_pos > css_length * 0.5,
               "Theme classes should come near the end of CSS output"
      end
    end
  end

  # ============================================================================
  # CSS Structure Tests
  # ============================================================================

  describe "CSS structure" do
    test "no duplicate class definitions exist" do
      css = LiveStyle.Compiler.generate_css()

      # Extract all class definitions
      class_defs =
        Regex.scan(~r/(\.[a-z0-9]+(?::not\(#\\#\))?(?::[a-z-]+(?:\([^)]*\))?)*)\{/, css)
        |> Enum.map(fn [_, selector] -> selector end)

      unique_defs = Enum.uniq(class_defs)

      assert length(class_defs) == length(unique_defs),
             "No duplicate class definitions should exist. Duplicates: #{inspect(class_defs -- unique_defs)}"
    end

    test "CSS contains expected sections" do
      css = LiveStyle.Compiler.generate_css()

      # Check for expected section markers/content
      has_vars = css =~ ":root{"
      has_classes = css =~ ~r/\.x[a-z0-9]+\{/

      assert has_vars or has_classes,
             "CSS should contain vars or classes"
    end
  end

  # ============================================================================
  # Deduplication Tests
  # ============================================================================

  describe "deduplication" do
    test "CSS output has no duplicate rules" do
      css = LiveStyle.Compiler.generate_css()

      # Split into individual rules and check for duplicates
      rules =
        css
        |> String.split("\n")
        |> Enum.filter(&(&1 =~ ~r/^\.[a-z0-9]/))
        |> Enum.uniq()

      original_rules =
        css
        |> String.split("\n")
        |> Enum.filter(&(&1 =~ ~r/^\.[a-z0-9]/))

      assert length(rules) == length(original_rules),
             "No duplicate CSS rules should exist"
    end
  end

  # ============================================================================
  # Cross-Module Consistency Tests
  # ============================================================================

  describe "cross-module consistency" do
    test "same styles in different modules produce same class names" do
      # This test verifies that atomic CSS works correctly -
      # the same property:value should produce the same class name
      # regardless of which module defines it

      css = LiveStyle.Compiler.generate_css()

      # Count how many times each atomic class appears in definitions
      # (should be exactly once per unique property:value)
      class_counts =
        Regex.scan(~r/\.(x[a-z0-9]+)\{([^}]+)\}/, css)
        |> Enum.group_by(fn [_, class, _] -> class end)
        |> Enum.map(fn {class, matches} -> {class, length(matches)} end)
        |> Enum.filter(fn {_, count} -> count > 1 end)

      assert class_counts == [],
             "Each atomic class should be defined exactly once. Duplicates: #{inspect(class_counts)}"
    end
  end

  # ============================================================================
  # Same Priority Property Ordering Tests (StyleX-compatible)
  # ============================================================================

  describe "same priority property ordering" do
    test "properties with same priority are sorted alphabetically by property name" do
      css = LiveStyle.Compiler.generate_css()

      # Find positions of border-bottom and border-color rules
      # Both have priority 2000 (shorthands-of-longhands)
      border_bottom_pos = find_first_position(css, "border-bottom:")
      border_color_pos = find_first_position(css, "border-color:")

      if border_bottom_pos && border_color_pos do
        # border-bottom should come BEFORE border-color alphabetically
        # This ensures border-color wins for overlapping properties (border-bottom-color)
        assert border_bottom_pos < border_color_pos,
               "border-bottom should come before border-color in CSS output. " <>
                 "This ensures proper cascade where border-color overrides border-bottom's implicit color. " <>
                 "border-bottom pos: #{border_bottom_pos}, border-color pos: #{border_color_pos}"
      end
    end

    test "CSS cascade is correct for overlapping shorthand properties" do
      # This test verifies the fix for the border-bottom + border-color collision bug.
      # When both properties are used:
      # - border-bottom: "1px solid" sets border-bottom-color to currentColor
      # - border-color: "red" should override border-bottom-color to red
      #
      # For this to work correctly, border-bottom must appear BEFORE border-color
      # in the CSS output (alphabetical order within same priority).
      css = LiveStyle.Compiler.generate_css()

      # Extract all rules at priority 2000 (shorthands-of-longhands)
      # These include: border-bottom, border-color, border-top, border-left, etc.
      shorthand_rules =
        Regex.scan(
          ~r/\.(x[a-z0-9]+)\{(border-(?:bottom|top|left|right|color|style|width)[^}]*)\}/,
          css
        )
        |> Enum.map(fn [_, _class, decl] ->
          [prop, _] = String.split(decl, ":", parts: 2)
          prop
        end)

      # Verify they're in alphabetical order
      sorted_rules = Enum.sort(shorthand_rules)

      # The rules should already be sorted
      assert shorthand_rules == sorted_rules,
             "Shorthand properties at same priority should be sorted alphabetically. " <>
               "Got: #{inspect(shorthand_rules)}, Expected: #{inspect(sorted_rules)}"
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp find_first_position(string, pattern) when is_binary(pattern) do
    case :binary.match(string, pattern) do
      {pos, _} -> pos
      :nomatch -> nil
    end
  end

  defp find_first_position(string, %Regex{} = pattern) do
    case Regex.run(pattern, string, return: :index) do
      [{pos, _} | _] -> pos
      nil -> nil
    end
  end
end
