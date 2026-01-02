defmodule LiveStyle.PseudoTest do
  @moduledoc """
  Tests for pseudo-classes and pseudo-elements.
  """
  use LiveStyle.TestCase

  defmodule PseudoClassModule do
    use LiveStyle

    class(:hover_effect,
      color: [
        default: "blue",
        ":hover": "darkblue"
      ]
    )

    class(:focus_effect,
      outline: [
        default: "none",
        ":focus": "2px solid blue"
      ]
    )

    class(:active_effect,
      transform: [
        default: "none",
        ":active": "scale(0.95)"
      ]
    )

    class(:focus_visible_effect,
      box_shadow: [
        default: "none",
        ":focus-visible": "0 0 0 2px blue"
      ]
    )

    class(:disabled_effect,
      opacity: [
        default: "1",
        ":disabled": "0.5"
      ]
    )
  end

  defmodule PseudoElementModule do
    use LiveStyle

    class(:before_content,
      "::before": [
        content: "\"→\"",
        margin_right: "4px"
      ]
    )

    class(:after_content,
      "::after": [
        content: "\"←\"",
        margin_left: "4px"
      ]
    )

    class(:placeholder_style,
      "::placeholder": [
        color: "gray",
        opacity: "0.7"
      ]
    )
  end

  defmodule NestedPseudoModule do
    use LiveStyle

    class(:hover_before,
      color: [
        default: "black",
        ":hover": "blue"
      ],
      "::before": [
        content: "\"•\"",
        color: [
          default: "gray",
          ":hover": "blue"
        ]
      ]
    )
  end

  describe "pseudo-classes" do
    test ":hover generates hover selector" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":hover"
      assert css =~ "color:darkblue"
    end

    test ":focus generates focus selector" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":focus"
      assert css =~ "outline:2px solid blue"
    end

    test ":active generates active selector" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":active"
      # Value is normalized (0.95 -> .95)
      assert css =~ "scale(.95)"
    end

    test ":focus-visible generates focus-visible selector" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":focus-visible"
    end

    test ":disabled generates disabled selector" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":disabled"
      # Value is normalized (0.5 -> .5)
      assert css =~ "opacity:.5"
    end

    test "pseudo-class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(PseudoClassModule, [:hover_effect])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  describe "pseudo-elements" do
    test "::before generates before pseudo-element" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::before"
      assert css =~ "content"
    end

    test "::after generates after pseudo-element" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::after"
    end

    test "::placeholder generates placeholder pseudo-element" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::placeholder"
      assert css =~ "color:gray"
    end

    test "pseudo-element class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(PseudoElementModule, [:before_content])
      assert is_binary(attrs.class)
    end
  end

  describe "nested pseudo" do
    test "pseudo-class and pseudo-element can combine" do
      css = LiveStyle.Compiler.generate_css()
      # Should generate both hover and ::before styles
      assert css =~ ":hover"
      assert css =~ "::before"
    end
  end
end
