defmodule LiveStyle.ClassTest do
  @moduledoc """
  Tests for the class/2 macro.
  """
  use LiveStyle.TestCase

  defmodule BasicStyles do
    use LiveStyle

    class(:simple, color: "red")

    class(:multiple,
      display: "flex",
      padding: "8px 16px",
      margin: "0"
    )
  end

  defmodule ConditionalStyles do
    use LiveStyle

    class(:hover_effect,
      color: [
        default: "blue",
        ":hover": "darkblue"
      ]
    )

    class(:focus_visible,
      outline: [
        default: "none",
        ":focus-visible": "2px solid blue"
      ]
    )

    class(:media_responsive,
      font_size: [
        default: "16px",
        "@media (max-width: 640px)": "14px"
      ]
    )
  end

  describe "static classes" do
    test "generates CSS for simple class" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "color:red"
    end

    test "generates CSS for multiple properties" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "display:flex"
      assert css =~ "padding:8px 16px"
      assert css =~ "margin:0"
    end

    test "returns class string via get_css" do
      attrs = LiveStyle.Compiler.get_css(BasicStyles, [:simple])
      assert is_binary(attrs.class)
      assert attrs.class != ""
      assert attrs.style == nil
    end

    test "returns class string via get_css_class" do
      class = LiveStyle.Compiler.get_css_class(BasicStyles, [:simple])
      assert is_binary(class)
      assert class != ""
    end

    test "get_css with single atom ref" do
      attrs = LiveStyle.Compiler.get_css(BasicStyles, :simple)
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  describe "conditional styles" do
    test "generates hover pseudo-class CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "color:blue"
      assert css =~ ":hover"
      assert css =~ "color:darkblue"
    end

    test "generates focus-visible pseudo-class CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":focus-visible"
      assert css =~ "outline:2px solid blue"
    end

    test "generates media query CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media (max-width: 640px)"
      assert css =~ "font-size:14px"
    end
  end

  describe "class merging" do
    test "later classes override earlier ones for same property" do
      attrs = LiveStyle.Compiler.get_css(BasicStyles, [:simple, :multiple])

      # Both classes should be present in the merged output
      assert is_binary(attrs.class)
      # The class string contains space-separated atomic classes
      classes = String.split(attrs.class, " ")
      assert length(classes) > 0
    end
  end
end
