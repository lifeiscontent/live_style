defmodule LiveStyle.ThemeClassesTest do
  @moduledoc """
  Tests for the theme/2 macro and theme_class/1 reference.
  """
  use LiveStyle.TestCase

  defmodule ThemeModule do
    use LiveStyle

    vars(
      white: "#ffffff",
      primary: "#3b82f6",
      background: "#f0f0f0"
    )

    theme(:dark,
      white: "#1a1a1a",
      primary: "#60a5fa",
      background: "#0a0a0a"
    )

    theme(:high_contrast,
      white: "#ffffff",
      primary: "#0000ff",
      background: "#000000"
    )

    class(:card,
      color: var(:white),
      background_color: var(:background)
    )
  end

  describe "theme definition" do
    test "generates theme class with variable overrides" do
      css = LiveStyle.Compiler.generate_css()
      # Theme should generate a class that overrides CSS variables
      assert css =~ "#1a1a1a"
      assert css =~ "#60a5fa"
      assert css =~ "#0a0a0a"
    end

    test "generates multiple themes" do
      css = LiveStyle.Compiler.generate_css()
      # Both dark and high_contrast themes should be in CSS
      assert css =~ "#0000ff"
      assert css =~ "#000000"
    end
  end

  describe "theme reference" do
    test "theme/1 returns class name string" do
      # Theme references return the theme class name
      theme_class = LiveStyle.ThemeClass.ref({ThemeModule, :dark})
      assert is_binary(theme_class)
      assert theme_class != ""
    end

    test "theme class appears in CSS output" do
      css = LiveStyle.Compiler.generate_css()
      theme_class = LiveStyle.ThemeClass.ref({ThemeModule, :dark})
      # The theme class should be in the CSS
      assert css =~ theme_class
    end
  end

  describe "theme with vars" do
    test "card class uses var references" do
      css = LiveStyle.Compiler.generate_css()
      # Card should use var() references (--x prefix from config)
      assert css =~ ~r/color:var\(--x[a-z0-9]+\)/
      assert css =~ ~r/background-color:var\(--x[a-z0-9]+\)/
    end

    test "card returns valid class string" do
      attrs = LiveStyle.Compiler.get_css(ThemeModule, [:card])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  describe "theme variable prefix consistency" do
    test "theme overrides use same variable names as base vars" do
      css = LiveStyle.Compiler.generate_css()

      # The dark theme overrides white: "#ffffff" -> "#1a1a1a"
      # Find the variable name that has value #1a1a1a (unique to dark theme's white override)
      theme_override_match =
        Regex.run(~r/(--x[a-z0-9]+):#1a1a1a/, css, capture: :all_but_first)

      assert theme_override_match,
             "Should find theme override variable with #1a1a1a value"

      [theme_var_name] = theme_override_match

      # The base vars in :root should have the SAME variable name with #ffffff
      [root_vars] = Regex.run(~r/:root\{([^}]+)\}/, css, capture: :all_but_first)

      assert root_vars =~ "#{theme_var_name}:#ffffff",
             "Base var #{theme_var_name} should exist in :root with #ffffff value. " <>
               "If this fails with a different prefix (like --v), the theme is not " <>
               "using the same variable names as the base vars."
    end

    test "theme variables use config prefix, not hardcoded prefix" do
      css = LiveStyle.Compiler.generate_css()

      # All theme variable overrides should use --x prefix (from Config.class_name_prefix)
      # not --v prefix (which was the bug)
      theme_class = LiveStyle.ThemeClass.ref({ThemeModule, :dark})

      # Find the theme class block
      theme_pattern = Regex.compile!("\\.#{theme_class}[^{]*\\{([^}]+)\\}")
      [theme_vars] = Regex.run(theme_pattern, css, capture: :all_but_first)

      # Should have --x prefixed variables
      assert theme_vars =~ ~r/--x[a-z0-9]+:/,
             "Theme variables should use --x prefix"

      # Should NOT have --v prefixed variables (the old bug)
      refute theme_vars =~ ~r/--v[a-z0-9]+:/,
             "Theme variables should NOT use hardcoded --v prefix"
    end
  end
end
