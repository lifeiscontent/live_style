defmodule LiveStyle.AtRulesTest do
  @moduledoc """
  Tests for CSS at-rules (@media, @supports, @container, @starting-style).

  These tests mirror StyleX's transform-stylex-create-test.js at-rule
  sections to ensure LiveStyle handles them the same way.
  """
  use LiveStyle.TestCase
  use Snapshy

  alias LiveStyle.Compiler
  alias LiveStyle.Compiler.CSS.Priority

  # ============================================================================
  # Media Queries
  # ============================================================================

  defmodule MediaQueries do
    use LiveStyle

    class(:responsive,
      background_color: [
        default: "red",
        "@media (min-width: 1000px)": "blue",
        "@media (min-width: 2000px)": "purple"
      ]
    )

    class(:font_responsive,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": "2rem"
      ]
    )
  end

  defmodule MediaQueryNoDefault do
    use LiveStyle

    # StyleX supports conditional objects without a default branch:
    # maxWidth: { '@media (min-width: 800px)': '800px' }
    class(:root,
      max_width: ["@media (min-width: 800px)": "800px"]
    )
  end

  defmodule MediaQueryWithPseudo do
    use LiveStyle

    class(:hover_in_media,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": [
          default: "2rem",
          ":hover": "2.2rem"
        ]
      ]
    )
  end

  defmodule ReducedMotionKeyframes do
    use LiveStyle

    keyframes(:shift,
      from: %{opacity: "0"},
      to: %{opacity: "1"}
    )

    class(:animated,
      animation_name: [
        default: keyframes(:shift),
        ":hover": keyframes(:shift),
        "@media (prefers-reduced-motion: reduce)": [
          default: "none",
          ":hover": "none"
        ]
      ]
    )
  end

  # ============================================================================
  # Supports Queries
  # ============================================================================

  defmodule SupportsQueries do
    use LiveStyle

    class(:hover_support,
      background_color: [
        default: "red",
        "@supports (hover: hover)": "blue",
        "@supports not (hover: hover)": "purple"
      ]
    )

    # @supports selector() syntax for feature detection
    class(:has_support,
      display: [
        default: "block",
        "@supports selector(:has(*))": "grid"
      ]
    )
  end

  # ============================================================================
  # Container Queries
  # ============================================================================

  defmodule ContainerQueries do
    use LiveStyle

    class(:container,
      font_size: [
        default: "1rem",
        "@container (min-width: 400px)": "2rem"
      ]
    )
  end

  # ============================================================================
  # Starting Style (Entry Animations)
  # ============================================================================

  defmodule StartingStyle do
    use LiveStyle

    # Basic @starting-style for entry animations
    class(:fade_in,
      opacity: %{
        :default => "1",
        "@starting-style" => "0"
      }
    )

    # @starting-style with transform
    class(:scale_in,
      transform: %{
        :default => "scale(1)",
        "@starting-style" => "scale(0.9)"
      }
    )

    # Multiple properties with @starting-style
    class(:slide_in,
      opacity: %{
        :default => "1",
        "@starting-style" => "0"
      },
      transform: %{
        :default => "translateY(0)",
        "@starting-style" => "translateY(-20px)"
      }
    )

    # @starting-style with nested pseudo-class (StyleX pattern)
    class(:hover_fade,
      opacity: %{
        :default => "1",
        "@starting-style" => %{
          :default => "0",
          ":hover" => "0.5"
        }
      }
    )
  end

  # ============================================================================
  # Triple-Nested Conditions
  # ============================================================================

  defmodule TripleNested do
    use LiveStyle

    # Triple nested: @media -> @supports -> :hover
    class(:triple_nested,
      color: [
        default: "black",
        "@media (min-width: 800px)": [
          default: "gray",
          "@supports (color: oklch(0 0 0))": [
            default: "oklch(0.5 0.2 250)",
            ":hover": "oklch(0.7 0.3 250)"
          ]
        ]
      ]
    )
  end

  # ============================================================================
  # Additional At-Rule Scenarios
  # ============================================================================

  defmodule NestedAtRules do
    use LiveStyle

    # Nested at-rules: @supports wrapping @media
    # StyleX test: "tokens object with nested @-rules"
    vars(
      color: %{
        default: "blue",
        "@media (prefers-color-scheme: dark)": %{
          default: "lightblue",
          "@supports (color: oklab(0 0 0))": "oklab(0.7 -0.3 -0.4)"
        }
      }
    )
  end

  defmodule MultipleMediaQueries do
    use LiveStyle

    # Multiple different media queries on same property
    class(:responsive,
      padding: [
        default: "8px",
        "@media (min-width: 640px)": "16px",
        "@media (min-width: 768px)": "24px",
        "@media (min-width: 1024px)": "32px",
        "@media (min-width: 1280px)": "48px"
      ]
    )
  end

  defmodule MediaQueryTypes do
    use LiveStyle

    # Different types of media queries
    class(:print,
      display: [
        default: "block",
        "@media print": "none"
      ]
    )

    class(:dark_mode,
      background_color: [
        default: "white",
        "@media (prefers-color-scheme: dark)": "black"
      ]
    )

    class(:reduced_motion,
      transition: [
        default: "all 0.3s ease",
        "@media (prefers-reduced-motion: reduce)": "none"
      ]
    )

    class(:max_width,
      font_size: [
        default: "16px",
        "@media (max-width: 640px)": "14px"
      ]
    )
  end

  defmodule SupportsQueryTypes do
    use LiveStyle

    # Different types of @supports queries
    class(:grid_support,
      display: [
        default: "flex",
        "@supports (display: grid)": "grid"
      ]
    )

    class(:gap_support,
      margin: [
        default: "10px",
        "@supports (gap: 10px)": "0"
      ]
    )

    class(:aspect_ratio_support,
      padding_bottom: [
        default: "56.25%",
        "@supports (aspect-ratio: 16 / 9)": "0"
      ]
    )
  end

  defmodule ContainerQueryTypes do
    use LiveStyle

    # Different container query conditions
    class(:inline_size,
      font_size: [
        default: "1rem",
        "@container (inline-size > 300px)": "1.25rem"
      ]
    )

    class(:named_container,
      padding: [
        default: "8px",
        "@container sidebar (min-width: 200px)": "16px"
      ]
    )
  end

  # ============================================================================
  # Snapshot Tests - Media Queries
  # ============================================================================

  describe "media queries" do
    test_snapshot "responsive background-color with media queries CSS output" do
      class_string = Compiler.get_css_class(MediaQueries, [:responsive])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "font responsive with media query CSS output" do
      class_string = Compiler.get_css_class(MediaQueries, [:font_responsive])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "media query without default CSS output" do
      class_string = Compiler.get_css_class(MediaQueryNoDefault, [:root])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  describe "media query with pseudo-class" do
    test_snapshot "pseudo-class inside media query CSS output" do
      class_string = Compiler.get_css_class(MediaQueryWithPseudo, [:hover_in_media])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "reduced-motion keyframes override CSS output" do
      class_string = Compiler.get_css_class(ReducedMotionKeyframes, [:animated])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Supports Queries
  # ============================================================================

  describe "supports queries" do
    test_snapshot "@supports hover CSS output" do
      class_string = Compiler.get_css_class(SupportsQueries, [:hover_support])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@supports selector() CSS output" do
      class_string = Compiler.get_css_class(SupportsQueries, [:has_support])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Container Queries
  # ============================================================================

  describe "container queries" do
    test_snapshot "@container CSS output" do
      class_string = Compiler.get_css_class(ContainerQueries, [:container])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "@container rules use specificity boost selector" do
      css = Compiler.generate_css()

      # Look for pattern like .class:not(#\#) inside @container
      assert css =~ ~r/@container[^{]+\{\.[a-z0-9]+:not\(#\\#\)\{/
    end
  end

  # ============================================================================
  # Snapshot Tests - @starting-style
  # ============================================================================

  describe "@starting-style" do
    test_snapshot "basic @starting-style CSS output" do
      class_string = Compiler.get_css_class(StartingStyle, [:fade_in])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@starting-style with transform CSS output" do
      class_string = Compiler.get_css_class(StartingStyle, [:scale_in])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "multiple properties with @starting-style CSS output" do
      class_string = Compiler.get_css_class(StartingStyle, [:slide_in])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@starting-style with nested pseudo-class CSS output" do
      class_string = Compiler.get_css_class(StartingStyle, [:hover_fade])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "@starting-style rules use specificity boost selector" do
      css = Compiler.generate_css()

      # Should have specificity boost selector like .class:not(#\#) inside @starting-style
      assert css =~ ~r/@starting-style\{\.[a-z0-9]+:not\(#\\#\)\{/
    end
  end

  # ============================================================================
  # Snapshot Tests - Triple Nested
  # ============================================================================

  describe "triple-nested conditions" do
    test_snapshot "triple nested @media @supports :hover CSS output" do
      class_string = Compiler.get_css_class(TripleNested, [:triple_nested])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Nested At-Rules in Vars
  # ============================================================================

  describe "nested at-rules" do
    test_snapshot "nested @supports inside @media for vars CSS output" do
      css = Compiler.generate_css()

      color_var = LiveStyle.Vars.lookup!({NestedAtRules, :color})
      var_name = color_var.ident

      # Extract all :root rules containing this variable
      css
      |> extract_var_rules(var_name)
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Multiple Media Queries
  # ============================================================================

  describe "multiple media queries" do
    test_snapshot "bounded media queries for consecutive min-width values CSS output" do
      class_string = Compiler.get_css_class(MultipleMediaQueries, [:responsive])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Media Query Types
  # ============================================================================

  describe "media query types" do
    test_snapshot "@media print CSS output" do
      class_string = Compiler.get_css_class(MediaQueryTypes, [:print])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@media (prefers-color-scheme: dark) CSS output" do
      class_string = Compiler.get_css_class(MediaQueryTypes, [:dark_mode])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@media (prefers-reduced-motion: reduce) CSS output" do
      class_string = Compiler.get_css_class(MediaQueryTypes, [:reduced_motion])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@media (max-width) CSS output" do
      class_string = Compiler.get_css_class(MediaQueryTypes, [:max_width])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Supports Query Types
  # ============================================================================

  describe "supports query types" do
    test_snapshot "@supports (display: grid) CSS output" do
      class_string = Compiler.get_css_class(SupportsQueryTypes, [:grid_support])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@supports (gap) CSS output" do
      class_string = Compiler.get_css_class(SupportsQueryTypes, [:gap_support])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@supports (aspect-ratio) CSS output" do
      class_string = Compiler.get_css_class(SupportsQueryTypes, [:aspect_ratio_support])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Snapshot Tests - Container Query Types
  # ============================================================================

  describe "container query types" do
    test_snapshot "@container (inline-size) CSS output" do
      class_string = Compiler.get_css_class(ContainerQueryTypes, [:inline_size])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "@container with named container CSS output" do
      class_string = Compiler.get_css_class(ContainerQueryTypes, [:named_container])

      class_string
      |> extract_all_rules()
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end

  # ============================================================================
  # Priority Tests (keeping these as assertions since they test internal priority logic)
  # ============================================================================

  describe "at-rule priority ordering" do
    test "at-rules have correct relative priority" do
      # @supports < @media < @container
      assert Priority.get_at_rule_priority("@supports (x)") == 30
      assert Priority.get_at_rule_priority("@media (x)") == 200
      assert Priority.get_at_rule_priority("@container (x)") == 300

      supports_priority = Priority.calculate("color", nil, "@supports (x)")
      media_priority = Priority.calculate("color", nil, "@media (x)")

      container_priority =
        Priority.calculate("color", nil, "@container (x)")

      assert supports_priority == 3030
      assert media_priority == 3200
      assert container_priority == 3300

      assert supports_priority < media_priority
      assert media_priority < container_priority
    end

    test "@starting-style has correct priority relative to other at-rules" do
      # @starting-style: 20 (should be lower than @supports)
      # @supports: 30
      # @media: 200
      # @container: 300
      assert Priority.get_at_rule_priority("@starting-style") == 20
      assert Priority.get_at_rule_priority("@supports (x)") == 30
      assert Priority.get_at_rule_priority("@media (x)") == 200
      assert Priority.get_at_rule_priority("@container (x)") == 300

      # @starting-style should have lowest at-rule priority
      starting_priority = Priority.get_at_rule_priority("@starting-style")
      supports_priority = Priority.get_at_rule_priority("@supports (x)")
      assert starting_priority < supports_priority
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

    # Pattern for various rule formats:
    # 1. Simple: .class{...}
    # 2. Pseudo-class: .class:not(#\#):hover{...}
    # 3. At-rule wrapped: @media{.class:not(#\#){...}} or @media{.class.class{...}}
    # 4. Nested at-rules: @supports{@media{.class{...}}}
    patterns = [
      # Simple and pseudo-class rules (with optional :not(#\#) specificity boost)
      ~r/\.#{escaped_class}(?::not\(#\\#\))?(?::[^{]+)?\{[^}]+\}/,
      # @media wrapped rules (with specificity boost :not(#\#) or doubled selector)
      ~r/@media[^{]+\{\.#{escaped_class}(?::not\(#\\#\)|\.#{escaped_class})(?::[^{]+)?\{[^}]+\}\}/,
      # @supports wrapped rules
      ~r/@supports[^{]+\{\.#{escaped_class}(?::not\(#\\#\)|\.#{escaped_class})(?::[^{]+)?\{[^}]+\}\}/,
      # @container wrapped rules
      ~r/@container[^{]+\{\.#{escaped_class}(?::not\(#\\#\)|\.#{escaped_class})(?::[^{]+)?\{[^}]+\}\}/,
      # @starting-style wrapped rules
      ~r/@starting-style(?::[^{]+)?\{\.#{escaped_class}(?::not\(#\\#\)|\.#{escaped_class})(?::[^{]+)?\{[^}]+\}\}/,
      # Nested at-rules: @supports{@media{...}}
      ~r/@supports[^{]+\{@media[^{]+\{\.#{escaped_class}(?::not\(#\\#\)|\.#{escaped_class})(?::[^{]+)?\{[^}]+\}\}\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, css) |> List.flatten()
    end)
  end

  defp extract_var_rules(css, var_name) do
    escaped_var = Regex.escape(var_name)

    # Patterns for :root rules containing the variable
    patterns = [
      # Simple :root rule
      ~r/:root\{[^}]*#{escaped_var}:[^;]+;[^}]*\}/,
      # @media wrapped :root rule
      ~r/@media[^{]+\{:root\{[^}]*#{escaped_var}:[^;]+;[^}]*\}\}/,
      # @supports wrapped :root rule
      ~r/@supports[^{]+\{:root\{[^}]*#{escaped_var}:[^;]+;[^}]*\}\}/,
      # Nested: @supports{@media{:root{...}}}
      ~r/@supports[^{]+\{@media[^{]+\{:root\{[^}]*#{escaped_var}:[^;]+;[^}]*\}\}\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, css) |> List.flatten()
    end)
  end
end
