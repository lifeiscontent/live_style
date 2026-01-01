defmodule LiveStyle.ThemesTest do
  @moduledoc """
  Comprehensive tests for LiveStyle's theme macro (StyleX's createTheme).

  These tests verify that LiveStyle's theme implementation matches StyleX's
  createTheme API behavior for:
  - Basic theme overrides
  - Themes with media query conditionals
  - Themes with nested @-rules
  - Multiple themes for the same variable set
  - Theme class generation

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-createTheme-test.js
  """
  use LiveStyle.TestCase
  use Snapshy

  # ===========================================================================
  # Test Modules - Basic themes
  # ===========================================================================

  defmodule BaseVars do
    use LiveStyle

    vars(
      color: "blue",
      other_color: "grey",
      radius: "10px"
    )

    theme(:custom,
      color: "green",
      other_color: "antiquewhite",
      radius: "6px"
    )
  end

  # ===========================================================================
  # Test Modules - Themes with media query conditionals
  # ===========================================================================

  defmodule ConditionalBaseVars do
    use LiveStyle

    vars(
      color: %{
        :default => "blue",
        "@media (prefers-color-scheme: dark)" => "lightblue",
        "@media print" => "white"
      },
      other_color: %{
        :default => "grey",
        "@media (prefers-color-scheme: dark)" => "rgba(0, 0, 0, 0.8)"
      },
      radius: "10px"
    )

    theme(:green_theme,
      color: %{
        :default => "green",
        "@media (prefers-color-scheme: dark)" => "lightgreen",
        "@media print" => "transparent"
      },
      other_color: %{
        :default => "antiquewhite",
        "@media (prefers-color-scheme: dark)" => "floralwhite"
      },
      radius: "6px"
    )
  end

  # ===========================================================================
  # Test Modules - Themes with nested @-rules
  # ===========================================================================

  defmodule NestedBaseVars do
    use LiveStyle

    vars(
      color: "blue",
      other_color: "grey"
    )

    theme(:nested,
      color: %{
        :default => "green",
        "@media (prefers-color-scheme: dark)" => "lightgreen"
      },
      other_color: %{
        :default => "antiquewhite",
        "@media (prefers-color-scheme: dark)" => %{
          :default => "floralwhite",
          "@supports (color: oklab(0 0 0))" => "oklab(0.7 -0.3 -0.4)"
        }
      }
    )
  end

  # ===========================================================================
  # Test Modules - Multiple themes for same variable set
  # ===========================================================================

  defmodule SharedVars do
    use LiveStyle

    vars(
      primary: "blue",
      secondary: "green",
      accent: "purple"
    )

    theme(:dark,
      primary: "lightblue",
      secondary: "lightgreen",
      accent: "lavender"
    )

    theme(:high_contrast,
      primary: "white",
      secondary: "yellow",
      accent: "cyan"
    )

    theme(:warm,
      primary: "orange",
      secondary: "coral",
      accent: "gold"
    )
  end

  # ===========================================================================
  # Test Modules - Partial theme overrides
  # ===========================================================================

  defmodule FullVars do
    use LiveStyle

    vars(
      text_color: "black",
      bg_color: "white",
      border_color: "gray",
      shadow_color: "rgba(0,0,0,0.1)"
    )

    # Only override some variables, not all
    theme(:partial,
      text_color: "blue",
      bg_color: "lightblue"
    )

    # border_color and shadow_color are not overridden
  end

  # ===========================================================================
  # Test Modules - Theme CSS output format
  # ===========================================================================

  defmodule CSSFormatVars do
    use LiveStyle

    vars(
      color: "red",
      size: "10px"
    )

    theme(:format_test,
      color: "blue",
      size: "20px"
    )
  end

  # ===========================================================================
  # Test Modules - Cross-module theme references (external theme)
  # ===========================================================================

  defmodule ExternalVars do
    use LiveStyle

    vars(main_color: "navy")

    # Theme defined in same module
    theme(:alt, main_color: "teal")
  end

  # ===========================================================================
  # Test Modules - Theme with typed variables
  # ===========================================================================

  defmodule TypedBaseVars do
    use LiveStyle
    import LiveStyle.PropertyType

    vars(
      primary_color: color("blue"),
      rotation: angle("0deg"),
      duration: time("200ms")
    )

    theme(:animated,
      primary_color: "red",
      rotation: "45deg",
      duration: "500ms"
    )
  end

  # ===========================================================================
  # Test Modules - Edge cases
  # ===========================================================================

  defmodule EdgeVars do
    use LiveStyle

    vars(
      empty_string: "",
      zero: "0",
      complex_value: "rgba(0, 0, 0, 0.5)"
    )

    theme(:edge_theme,
      empty_string: "not-empty",
      zero: "1",
      complex_value: "hsla(0, 100%, 50%, 0.75)"
    )
  end

  # ===========================================================================
  # Tests - Basic themes
  # ===========================================================================

  describe "basic themes" do
    test "generates theme class with override values in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should generate .CLASS,.CLASS:root{...} format
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:green/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:antiquewhite/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:6px/
    end

    test "base variables are generated in :root" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:blue/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:grey/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:10px/
    end

    test "theme class can be retrieved via LiveStyle.Theme.ref/1" do
      theme_class = LiveStyle.Theme.ref({BaseVars, :custom})

      assert is_binary(theme_class)
      assert theme_class =~ ~r/^t[a-z0-9]+$/
    end
  end

  # ===========================================================================
  # Tests - Themes with media query conditionals
  # ===========================================================================

  describe "themes with media query conditionals" do
    test "theme generates default values in class" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should have default values
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:green/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:antiquewhite/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:6px/
    end

    test "theme generates media query wrapped overrides" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should have @media overrides
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lightgreen/

      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:floralwhite/

      assert css =~ ~r/@media print\{\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:transparent/
    end
  end

  # ===========================================================================
  # Tests - Themes with nested @-rules
  # ===========================================================================

  describe "themes with nested @-rules" do
    test "theme generates nested @supports inside @media" do
      css = LiveStyle.Compiler.generate_css()

      # Nested @supports inside @media for theme
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{@supports \(color: oklab\(0 0 0\)\)\{\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*oklab/
    end

    test "theme generates default and dark mode values" do
      css = LiveStyle.Compiler.generate_css()

      # Default value
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:green/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:antiquewhite/

      # Dark mode value
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lightgreen/
    end
  end

  # ===========================================================================
  # Tests - Multiple themes for same variable set
  # ===========================================================================

  describe "multiple themes for same variable set" do
    test "each theme generates unique class in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Dark theme values
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lightblue/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lightgreen/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lavender/

      # High contrast theme values
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:white/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:yellow/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:cyan/

      # Warm theme values
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:orange/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:coral/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:gold/
    end

    test "each theme returns unique class via LiveStyle.Theme.ref/1" do
      dark_class = LiveStyle.Theme.ref({SharedVars, :dark})
      high_contrast_class = LiveStyle.Theme.ref({SharedVars, :high_contrast})
      warm_class = LiveStyle.Theme.ref({SharedVars, :warm})

      assert dark_class != high_contrast_class
      assert high_contrast_class != warm_class
      assert warm_class != dark_class

      # All should be valid class names
      assert dark_class =~ ~r/^t[a-z0-9]+$/
      assert high_contrast_class =~ ~r/^t[a-z0-9]+$/
      assert warm_class =~ ~r/^t[a-z0-9]+$/
    end
  end

  # ===========================================================================
  # Tests - Partial theme overrides
  # ===========================================================================

  describe "partial theme overrides" do
    test "partial theme only overrides specified variables in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Should have overrides for text and bg (blue, lightblue)
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:blue/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:lightblue/
    end

    test "base variables still available in :root" do
      css = LiveStyle.Compiler.generate_css()

      # All base variables should be in :root
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:black/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:white/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:gray/
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:rgba\(0,0,0,0\.1\)/
    end
  end

  # ===========================================================================
  # Tests - Theme CSS output format
  # ===========================================================================

  describe "theme CSS output format" do
    test "theme CSS uses .CLASS,.CLASS:root selector format" do
      css = LiveStyle.Compiler.generate_css()
      theme_class = LiveStyle.Theme.ref({CSSFormatVars, :format_test})

      # StyleX format: .CLASS,.CLASS:root{...}
      assert css =~ ".#{theme_class},.#{theme_class}:root{"
    end

    test "theme CSS sets CSS variable values" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should override to blue and 20px
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:blue/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:20px/
    end
  end

  # ===========================================================================
  # Tests - Cross-module theme references
  # ===========================================================================

  describe "cross-module theme references" do
    test "theme class contains override value in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should override to teal
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:teal/
    end

    test "theme can be referenced via LiveStyle.Theme.ref/1" do
      theme_class = LiveStyle.Theme.ref({ExternalVars, :alt})

      assert is_binary(theme_class)
      assert theme_class =~ ~r/^t[a-z0-9]+$/
    end
  end

  # ===========================================================================
  # Tests - Theme with typed variables
  # ===========================================================================

  describe "theme with typed variables" do
    test "theme overrides typed variables in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should have overrides for typed vars
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:red/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:45deg/
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:500ms/
    end

    test "typed variables generate @property rules" do
      css = LiveStyle.Compiler.generate_css()

      # Original typed variables should have @property rules
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<color>"/
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<angle>"/
      assert css =~ ~r/@property --v[a-z0-9]+ \{ syntax: "<time>"/
    end
  end

  # ===========================================================================
  # Tests - Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "theme can override empty string values in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should override empty string to "not-empty"
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*:not-empty/
    end

    test "theme can override zero values in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should override 0 to 1
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*--v[a-z0-9]+:1[;}]/
    end

    test "theme can override complex CSS values" do
      css = LiveStyle.Compiler.generate_css()

      # Theme should override to hsla value
      assert css =~ ~r/\.t[a-z0-9]+,\.t[a-z0-9]+:root\{[^}]*hsla\(0, 100%, 50%, 0\.75\)/
    end
  end

  # ===========================================================================
  # CSS Output Snapshots
  # ===========================================================================

  describe "CSS output snapshots" do
    test_snapshot "basic theme CSS output" do
      css = LiveStyle.Compiler.generate_css()
      theme_class = LiveStyle.Theme.ref({BaseVars, :custom})

      # Extract theme rules
      css
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, theme_class))
      |> Enum.join("\n")
    end

    test_snapshot "multiple themes CSS output" do
      css = LiveStyle.Compiler.generate_css()

      dark_class = LiveStyle.Theme.ref({SharedVars, :dark})
      contrast_class = LiveStyle.Theme.ref({SharedVars, :high_contrast})
      warm_class = LiveStyle.Theme.ref({SharedVars, :warm})

      # Extract all theme rules
      css
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.contains?(line, dark_class) or
          String.contains?(line, contrast_class) or
          String.contains?(line, warm_class)
      end)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "conditional theme CSS output" do
      css = LiveStyle.Compiler.generate_css()
      theme_class = LiveStyle.Theme.ref({ConditionalBaseVars, :green_theme})

      # Extract theme rules including media queries
      css
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, theme_class))
      |> Enum.join("\n")
    end

    test_snapshot "nested at-rules theme CSS output" do
      css = LiveStyle.Compiler.generate_css()
      theme_class = LiveStyle.Theme.ref({NestedBaseVars, :nested})

      # Extract theme rules including nested @-rules
      css
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, theme_class))
      |> Enum.join("\n")
    end
  end
end
