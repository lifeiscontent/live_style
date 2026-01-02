defmodule LiveStyle.DynamicStylesTest do
  @moduledoc """
  Tests for dynamic classes (function-based styles with runtime values).
  """
  use LiveStyle.TestCase

  defmodule DynamicModule do
    use LiveStyle

    # Single parameter dynamic class
    class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)

    # Multiple parameters
    class(:dynamic_size, fn width, height -> [width: width, height: height] end)

    # With computed expression
    class(:dynamic_transform, fn x -> [transform: "translateX(#{x})"] end)

    # Static class for comparison
    class(:static_base, display: "block")
  end

  describe "dynamic class CSS output" do
    test "generates CSS with var() references for single param" do
      css = LiveStyle.Compiler.generate_css()
      # Dynamic classes should use CSS variables
      assert css =~ ~r/opacity:var\(--x[a-z0-9-]+\)/
    end

    test "generates CSS with var() references for multiple params" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ~r/width:var\(--x[a-z0-9-]+\)/
      assert css =~ ~r/height:var\(--x[a-z0-9-]+\)/
    end

    test "generates @property rules with inherits: false" do
      css = LiveStyle.Compiler.generate_css()
      # Dynamic CSS variables should have @property rules to prevent inheritance
      assert css =~ "@property"
      assert css =~ "inherits: false"
    end
  end

  describe "dynamic class runtime output" do
    test "returns class and style for single param" do
      attrs = LiveStyle.Compiler.get_css(DynamicModule, [{:dynamic_opacity, "0.5"}])
      assert is_binary(attrs.class)
      assert attrs.class != ""
      # Should have inline style with CSS variable
      assert is_binary(attrs.style)
      assert attrs.style =~ "0.5"
    end

    test "returns class and style for multiple params" do
      attrs = LiveStyle.Compiler.get_css(DynamicModule, [{:dynamic_size, ["100px", "200px"]}])
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      assert attrs.style =~ "100px"
      assert attrs.style =~ "200px"
    end

    test "computed expressions work at runtime" do
      attrs = LiveStyle.Compiler.get_css(DynamicModule, [{:dynamic_transform, "50px"}])
      assert is_binary(attrs.class)
      assert is_binary(attrs.style)
      assert attrs.style =~ "translateX(50px)"
    end
  end

  describe "mixing static and dynamic" do
    test "can combine static and dynamic classes" do
      attrs = LiveStyle.Compiler.get_css(DynamicModule, [:static_base, {:dynamic_opacity, "0.8"}])
      assert is_binary(attrs.class)
      # Class string contains both static and dynamic class names
      classes = String.split(attrs.class, " ")
      assert length(classes) > 1
      # Has style for dynamic value
      assert is_binary(attrs.style)
    end
  end

  describe "property-based merging for dynamic classes" do
    test "later dynamic class overrides earlier for same property" do
      # This tests StyleX-aligned property-based merging
      attrs =
        LiveStyle.Compiler.get_css(DynamicModule, [
          {:dynamic_opacity, "0.3"},
          {:dynamic_opacity, "0.9"}
        ])

      # Only the last value should be in style
      assert attrs.style =~ "0.9"
      refute attrs.style =~ "0.3"
    end
  end
end
