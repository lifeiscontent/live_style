defmodule LiveStyle.ViewTransitionTest do
  @moduledoc """
  Tests for view_transition/2 macro and view_transition/1 reference.
  """
  use LiveStyle.TestCase

  defmodule TransitionsModule do
    use LiveStyle

    keyframes(:fade_in,
      from: [opacity: "0"],
      to: [opacity: "1"]
    )

    keyframes(:fade_out,
      from: [opacity: "1"],
      to: [opacity: "0"]
    )

    view_transition(:card_transition,
      old: [animation_name: keyframes(:fade_out), animation_duration: "250ms"],
      new: [animation_name: keyframes(:fade_in), animation_duration: "250ms"]
    )

    view_transition(:slide_transition,
      group: [animation_duration: "300ms"],
      image_pair: [isolation: "isolate"]
    )
  end

  describe "view_transition definition" do
    test "generates ::view-transition CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::view-transition"
    end

    test "generates old pseudo-element styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::view-transition-old"
      # Value is normalized (250ms -> .25s)
      assert css =~ "animation-duration:.25s"
    end

    test "generates new pseudo-element styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::view-transition-new"
    end

    test "generates group pseudo-element styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::view-transition-group"
    end

    test "generates image-pair pseudo-element styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "::view-transition-image-pair"
      assert css =~ "isolation:isolate"
    end
  end

  describe "view_transition reference" do
    test "returns class name string" do
      class = LiveStyle.ViewTransition.ref({TransitionsModule, :card_transition})
      assert is_binary(class)
      assert class != ""
    end

    test "class name appears in CSS" do
      css = LiveStyle.Compiler.generate_css()
      class = LiveStyle.ViewTransition.ref({TransitionsModule, :card_transition})
      assert css =~ class
    end
  end
end
