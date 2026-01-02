defmodule LiveStyle.PositionTryTest do
  @moduledoc """
  Tests for position_try/2 macro and position_try/1 reference.
  """
  use LiveStyle.TestCase

  defmodule PositionDefinitions do
    use LiveStyle

    position_try(:bottom_fallback,
      top: "anchor(bottom)",
      left: "anchor(left)"
    )

    position_try(:right_fallback,
      top: "anchor(top)",
      left: "anchor(right)"
    )
  end

  defmodule PositionModule do
    use LiveStyle

    class(:tooltip,
      position: "absolute",
      position_try_fallbacks:
        position_try({LiveStyle.PositionTryTest.PositionDefinitions, :bottom_fallback})
    )
  end

  defmodule AnonymousPositionModule do
    use LiveStyle

    class(:dropdown,
      position: "absolute",
      # Anonymous position-try (inline declaration)
      position_try_fallbacks:
        position_try(
          bottom: "anchor(top)",
          left: "anchor(left)"
        )
    )
  end

  describe "position_try definition" do
    test "generates @position-try rule" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@position-try"
    end

    test "generates anchor positioning properties" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "anchor(bottom)"
      assert css =~ "anchor(left)"
    end
  end

  describe "position_try reference" do
    test "named reference returns dashed-ident" do
      ref = LiveStyle.PositionTry.ref({PositionDefinitions, :bottom_fallback})
      assert is_binary(ref)
      assert String.starts_with?(ref, "--")
    end

    test "reference appears in CSS" do
      css = LiveStyle.Compiler.generate_css()
      ref = LiveStyle.PositionTry.ref({PositionDefinitions, :bottom_fallback})
      assert css =~ ref
    end

    test "class using position_try returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(PositionModule, [:tooltip])
      assert is_binary(attrs.class)
    end
  end

  describe "anonymous position_try" do
    test "generates @position-try for inline declaration" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "anchor(top)"
    end

    test "dropdown class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(AnonymousPositionModule, [:dropdown])
      assert is_binary(attrs.class)
    end
  end
end
