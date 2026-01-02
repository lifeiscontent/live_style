defmodule LiveStyle.FallbackTest do
  @moduledoc """
  Tests for the fallback/1 function (StyleX firstThatWorks equivalent).
  """
  use LiveStyle.TestCase

  defmodule FallbackModule do
    use LiveStyle

    # Browser fallbacks
    class(:sticky,
      position: fallback(["sticky", "fixed"])
    )

    # CSS variable with fallback
    class(:themed,
      background_color: fallback(["var(--bg-color)", "#808080"])
    )

    # Multiple CSS variables with final fallback
    class(:multi_themed,
      color: fallback(["var(--primary)", "var(--fallback)", "black"])
    )
  end

  describe "browser fallbacks" do
    test "generates multiple declarations for same property" do
      css = LiveStyle.Compiler.generate_css()
      # Should generate both values - fallback first, then preferred
      assert css =~ "position:fixed"
      assert css =~ "position:sticky"
    end
  end

  describe "CSS variable fallbacks" do
    test "generates nested var() with fallback" do
      css = LiveStyle.Compiler.generate_css()
      # CSS variable fallbacks should be nested (no space after comma in minified output)
      assert css =~ "var(--bg-color,#808080)"
    end

    test "generates multiple nested var() fallbacks" do
      css = LiveStyle.Compiler.generate_css()
      # Multiple variables nest: var(--primary,var(--fallback,black))
      assert css =~ "var(--primary,var(--fallback,black))"
    end
  end

  describe "fallback class attrs" do
    test "sticky class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(FallbackModule, [:sticky])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "themed class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(FallbackModule, [:themed])
      assert is_binary(attrs.class)
    end
  end
end
