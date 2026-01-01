defmodule LiveStyle.VarsTest do
  @moduledoc """
  Tests for CSS variables (vars) and themes (theme).

  These tests mirror StyleX's transform-stylex-defineVars-test.js and
  transform-stylex-createTheme-test.js to ensure LiveStyle handles CSS
  variables the same way StyleX does.
  """
  use LiveStyle.TestCase
  use Snapshy

  # ============================================================================
  # Basic CSS Variables
  # ============================================================================

  describe "basic CSS variables" do
    defmodule BasicVars do
      use LiveStyle

      vars(
        primary: "red",
        secondary: "blue",
        tertiary: "green"
      )
    end

    test "generates CSS custom properties in :root" do
      css = LiveStyle.Compiler.generate_css()

      # Variables should be in :root with hashed names
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:red/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:blue/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:green/
    end
  end

  # ============================================================================
  # CSS Variables with Media Queries
  # ============================================================================

  describe "CSS variables with media queries" do
    defmodule VarsWithMediaQuery do
      use LiveStyle

      vars(
        background: %{
          default: "white",
          "@media (prefers-color-scheme: dark)": "black"
        }
      )
    end

    test "generates default value in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:white/
    end

    test "generates @media wrapped conditional value" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*--v[a-z0-9]+:black/
    end
  end

  # ============================================================================
  # CSS Variables with Nested @-rules
  # ============================================================================

  describe "CSS variables with nested @-rules" do
    defmodule VarsWithNestedAtRules do
      use LiveStyle

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

    test "generates default value in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:blue/
    end

    test "generates @media wrapped value for dark mode" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*--v[a-z0-9]+:lightblue/
    end

    test "generates nested @supports inside @media" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~
               ~r/@supports \(color: oklab\(0 0 0\)\)\{@media \(prefers-color-scheme: dark\)\{:root\{[^}]*--v[a-z0-9]+:oklab/
    end
  end

  # ============================================================================
  # Using CSS Variables in Classes
  # ============================================================================

  describe "using CSS variables in classes" do
    defmodule VarsUsedInRules do
      use LiveStyle

      vars(
        primary_color: "blue",
        text_size: "16px"
      )

      class(:styled,
        color: var(:primary_color),
        font_size: var(:text_size)
      )
    end

    test "generates var() references in class CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Should have class rules using var()
      assert css =~ ~r/color:var\(--v[a-z0-9]+\)/
      assert css =~ ~r/font-size:var\(--v[a-z0-9]+\)/
    end

    test "generates variable definitions in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:blue/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:16px/
    end
  end

  # ============================================================================
  # Using var/1 as a Custom Property Key
  # ============================================================================

  describe "using var/1 as a custom property key" do
    defmodule VarsUsedAsCustomPropertyKey do
      use LiveStyle

      vars(primary_color: "blue")

      class(:set_var, [
        {var(:primary_color), [default: "red", ":hover": "blue"]}
      ])
    end

    test "generates CSS that sets the custom property" do
      css = LiveStyle.Compiler.generate_css()

      # Should have rules that set the custom property directly
      assert css =~ ~r/--v[a-z0-9]+:red/
      assert css =~ ~r/--v[a-z0-9]+:blue/
    end
  end

  # ============================================================================
  # Themes
  # ============================================================================

  describe "themes" do
    defmodule ThemeVars do
      use LiveStyle

      vars(
        color: "red",
        bg: "white"
      )

      theme(:dark,
        color: "white",
        bg: "black"
      )

      theme(:high_contrast,
        color: "black",
        bg: "yellow"
      )
    end

    test "generates theme class that overrides variables" do
      css = LiveStyle.Compiler.generate_css()

      # Theme format is: .CLASS,.CLASS:root{--var:value;}
      # Dark theme should have overrides for white (color) and black (bg)
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*--v[a-z0-9]+:white/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*--v[a-z0-9]+:black/

      # High contrast theme should have overrides
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*--v[a-z0-9]+:yellow/
    end

    test "generates base variable values in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:red/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:white/
    end
  end

  # ============================================================================
  # Typed Variables
  # ============================================================================

  describe "typed variables" do
    defmodule TypedVars do
      use LiveStyle
      import LiveStyle.PropertyType

      vars(
        primary:
          color(%{
            default: "red",
            "@media (prefers-color-scheme: dark)": "white",
            "@media print": "black"
          }),
        angle_var: angle("0deg"),
        duration_var: time("200ms")
      )
    end

    test "generates @property rules for typed variables" do
      css = LiveStyle.Compiler.generate_css()

      # Should have @property rules with correct syntax
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<color>"/
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<angle>"/
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<time>"/
    end

    test "generates initial-value in @property rules" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/initial-value: red/
      assert css =~ ~r/initial-value: 0deg/
      assert css =~ ~r/initial-value: 200ms/
    end

    test "generates conditional values for typed variables" do
      css = LiveStyle.Compiler.generate_css()

      # Default value
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:red/

      # @media dark mode override
      assert css =~ ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*--v[a-z0-9]+:white/

      # @media print override
      assert css =~ ~r/@media print\{:root\{[^}]*--v[a-z0-9]+:black/
    end
  end

  # ============================================================================
  # Cross-module Variable References
  # ============================================================================

  describe "cross-module variable references" do
    defmodule SharedVars do
      use LiveStyle

      vars(shared_color: "purple")
    end

    defmodule VarsConsumer do
      use LiveStyle
      alias LiveStyle.VarsTest.SharedVars

      class(:using_shared,
        color: var({SharedVars, :shared_color})
      )
    end

    test "generates var() reference for cross-module variable" do
      css = LiveStyle.Compiler.generate_css()

      # Should have var() reference in class
      assert css =~ ~r/color:var\(--v[a-z0-9]+\)/
    end

    test "generates shared variable definition in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:purple/
    end
  end

  # ============================================================================
  # CSS Output Snapshots
  # ============================================================================

  describe "CSS output snapshots" do
    test_snapshot "basic vars CSS output" do
      # BasicVars defines: primary: "red", secondary: "blue", tertiary: "green"
      extract_css_with_values(["red", "blue", "green"])
    end

    test_snapshot "vars with media query CSS output" do
      # VarsWithMediaQuery: background white/black with dark mode media query
      extract_css_with_values(["white", "black", "prefers-color-scheme"])
    end

    test_snapshot "vars with nested at-rules CSS output" do
      # VarsWithNestedAtRules: blue/lightblue/oklab with nested @supports/@media
      extract_css_with_values(["lightblue", "oklab", "@supports"])
    end

    test_snapshot "vars used in rules CSS output" do
      # VarsUsedInRules: primary_color: blue, text_size: 16px, class :styled
      css = LiveStyle.Compiler.generate_css()

      css
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.contains?(line, "16px") or
          (String.contains?(line, "var(--v") and
             (String.contains?(line, "color") or String.contains?(line, "font-size")))
      end)
      |> Enum.join("\n")
    end

    test_snapshot "typed vars CSS output" do
      # TypedVars: @property rules with <color>, <angle>, <time>
      css = LiveStyle.Compiler.generate_css()

      css
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.starts_with?(line, "@property") or
          String.contains?(line, "0deg") or
          String.contains?(line, "200ms")
      end)
      |> Enum.join("\n")
    end

    test_snapshot "cross-module vars CSS output" do
      # SharedVars: shared_color: purple
      extract_css_with_values(["purple"])
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp extract_css_with_values(patterns) do
    css = LiveStyle.Compiler.generate_css()

    css
    |> String.split("\n")
    |> Enum.filter(fn line ->
      Enum.any?(patterns, fn pattern -> String.contains?(line, pattern) end)
    end)
    |> Enum.join("\n")
  end
end
