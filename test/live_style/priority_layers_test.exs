defmodule LiveStyle.Compiler.CSS.PriorityLayersTest do
  @moduledoc """
  Tests for CSS layers feature - default behavior (layers disabled).

  When `use_css_layers: false` (default), LiveStyle uses the `:not(#\\#)`
  selector hack for specificity bumping, matching StyleX's default behavior.
  """
  use LiveStyle.TestCase

  # ============================================================================
  # Test Modules - Define styles with different priority levels
  # ============================================================================

  defmodule BasicStyles do
    use LiveStyle

    class(:color_style, color: "red")
    class(:background_style, background_color: "blue")
    class(:margin_style, margin: "10px")
    class(:margin_top_style, margin_top: "5px")
  end

  defmodule PseudoStyles do
    use LiveStyle

    class(:hover_style, color: [default: "blue", ":hover": "red"])
  end

  # ============================================================================
  # Tests - Default behavior (layers disabled)
  # ============================================================================

  describe "default behavior (layers disabled)" do
    test "does not use @layer blocks" do
      css = LiveStyle.Compiler.generate_css()
      refute css =~ "@layer "
    end

    test "uses :not(#\\#) hack for specificity bumping on conditional selectors" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":not(#\\#)"
    end

    test "rules from test modules are included in CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "color:red"
      assert css =~ "background-color:blue"
      assert css =~ "margin:10px"
    end
  end
end
