defmodule LiveStyle.DynamicStylesPrefixingTest do
  @moduledoc """
  Tests for dynamic styles with property prefixing.

  When prefix_css is configured, dynamic styles should have vendor prefixes
  applied in the generated CSS output.
  """
  use LiveStyle.TestCase,
    prefix_css: &__MODULE__.background_clip_prefixer/2

  @doc false
  def background_clip_prefixer(property, value) do
    if property == "background-clip" do
      "-webkit-background-clip:#{value};background-clip:#{value}"
    else
      "#{property}:#{value}"
    end
  end

  # ============================================================================
  # Test Modules
  # ============================================================================

  defmodule DynamicWithPrefixedProperty do
    use LiveStyle

    # background-clip requires -webkit-background-clip for Safari
    class(:clip, fn clip -> [background_clip: clip] end)
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "dynamic styles with property prefixing" do
    test "prefix_css applies vendor prefixes to dynamic style CSS output" do
      css = LiveStyle.Compiler.generate_css()

      # The CSS should include both the prefixed and standard properties
      # Dynamic styles use CSS variables for the value
      assert css =~ "-webkit-background-clip:var(--x-background-clip)"
      assert css =~ "background-clip:var(--x-background-clip)"
    end
  end
end
