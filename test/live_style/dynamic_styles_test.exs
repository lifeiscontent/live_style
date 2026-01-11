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

  defmodule VarOverrideModule do
    @moduledoc """
    Test module for CSS variable override via dynamic classes.
    This tests the pattern where you use var() references as property keys
    to override CSS variables defined elsewhere.
    """
    use LiveStyle

    # Define some CSS variables
    vars primary: "#3b82f6",
         secondary: "#10b981"

    # Dynamic class that overrides CSS variables
    # This is the key pattern: using var({Module, :name}) as the property key
    class(:theme_override, fn primary, secondary ->
      [
        {var(:primary), primary},
        {var(:secondary), secondary}
      ]
    end)

    # A class that uses these variables
    class(:themed,
      color: var(:primary),
      background_color: var(:secondary)
    )
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

  # A separate module for cross-module dynamic class testing
  defmodule CrossModuleConsumer do
    use LiveStyle

    # Just a static class for this module
    class(:consumer_class, display: "flex")
  end

  describe "cross-module dynamic class resolution" do
    test "can resolve dynamic class from another module" do
      # Use DynamicModule's dynamic class from CrossModuleConsumer's context
      attrs =
        LiveStyle.Compiler.get_css(CrossModuleConsumer, [
          {{DynamicModule, :dynamic_opacity}, "0.75"}
        ])

      assert is_binary(attrs.class)
      assert attrs.class != ""
      assert is_binary(attrs.style)
      assert attrs.style =~ "0.75"
    end

    test "can combine local and cross-module dynamic classes" do
      attrs =
        LiveStyle.Compiler.get_css(CrossModuleConsumer, [
          :consumer_class,
          {{DynamicModule, :dynamic_size}, ["50px", "100px"]}
        ])

      assert is_binary(attrs.class)
      classes = String.split(attrs.class, " ")
      # Should have consumer_class + the dynamic class(es)
      assert length(classes) >= 2
      assert is_binary(attrs.style)
      assert attrs.style =~ "50px"
      assert attrs.style =~ "100px"
    end

    test "cross-module static class reference still works" do
      attrs =
        LiveStyle.Compiler.get_css(CrossModuleConsumer, [
          {DynamicModule, :static_base}
        ])

      assert is_binary(attrs.class)
      assert attrs.class != ""
      # Static classes have no inline style
      assert is_nil(attrs.style)
    end
  end

  describe "CSS variable override via dynamic classes" do
    test "theme_override class returns valid attrs" do
      attrs =
        LiveStyle.Compiler.get_css(VarOverrideModule, [
          {:theme_override, ["#ff0000", "#00ff00"]}
        ])

      assert is_binary(attrs.class)
      assert attrs.class != ""
      assert is_binary(attrs.style)
    end

    test "inline style sets CSS variables directly (no extra prefix)" do
      attrs =
        LiveStyle.Compiler.get_css(VarOverrideModule, [
          {:theme_override, ["#ff0000", "#00ff00"]}
        ])

      # The inline style should set the CSS variables directly using their hashed names
      # e.g., "--x1abc123: #ff0000" NOT "--x---x1abc123: #ff0000"
      assert is_binary(attrs.style)

      # Should contain the values we passed
      assert attrs.style =~ "#ff0000"
      assert attrs.style =~ "#00ff00"

      # Should NOT have double dashes from incorrect prefixing (--x---x...)
      refute attrs.style =~ "--x---"
    end

    test "can combine themed class with theme_override" do
      attrs =
        LiveStyle.Compiler.get_css(VarOverrideModule, [
          :themed,
          {:theme_override, ["#ff0000", "#00ff00"]}
        ])

      # Should have both class names and inline style
      assert is_binary(attrs.class)
      classes = String.split(attrs.class, " ")
      assert length(classes) >= 1
      assert is_binary(attrs.style)
    end
  end
end
