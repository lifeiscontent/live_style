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
end
