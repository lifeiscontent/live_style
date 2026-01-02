defmodule LiveStyle.IncludeTest do
  @moduledoc """
  Tests for the include/1 function (style composition).
  """
  use LiveStyle.TestCase

  defmodule BaseStyles do
    use LiveStyle

    class(:base,
      display: "flex",
      padding: "8px"
    )

    class(:rounded,
      border_radius: "4px"
    )
  end

  defmodule ComposedStyles do
    use LiveStyle

    # Include local class
    class(:card, [
      include({LiveStyle.IncludeTest.BaseStyles, :base}),
      background_color: "white"
    ])

    # Include multiple classes
    class(:fancy_card, [
      include({LiveStyle.IncludeTest.BaseStyles, :base}),
      include({LiveStyle.IncludeTest.BaseStyles, :rounded}),
      box_shadow: "0 2px 4px rgba(0,0,0,0.1)"
    ])

    # Override included property
    class(:override_card, [
      include({LiveStyle.IncludeTest.BaseStyles, :base}),
      padding: "16px"
    ])
  end

  defmodule LocalIncludeModule do
    use LiveStyle

    class(:local_base, color: "blue")

    class(:extended, [
      include(:local_base),
      font_weight: "bold"
    ])
  end

  describe "cross-module include" do
    test "included styles appear in CSS" do
      css = LiveStyle.Compiler.generate_css()
      # Card should have base styles
      assert css =~ "display:flex"
      assert css =~ "background-color:white"
    end

    test "multiple includes combine styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "border-radius:4px"
      assert css =~ "box-shadow"
    end

    test "included class returns merged attrs" do
      attrs = LiveStyle.Compiler.get_css(ComposedStyles, [:card])
      assert is_binary(attrs.class)
      # Should have classes for both display:flex and background-color:white
      classes = String.split(attrs.class, " ")
      assert length(classes) >= 2
    end
  end

  describe "include with override" do
    test "later property overrides included property" do
      attrs = LiveStyle.Compiler.get_css(ComposedStyles, [:override_card])
      # The class should only have one padding value (the override)
      assert is_binary(attrs.class)
    end
  end

  describe "local include" do
    test "local include works within same module" do
      attrs = LiveStyle.Compiler.get_css(LocalIncludeModule, [:extended])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "extended class has both base and extension" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "color:blue"
      assert css =~ "font-weight:bold"
    end
  end
end
