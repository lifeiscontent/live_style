defmodule LiveStyle.KeyframesTest do
  @moduledoc """
  Tests for the keyframes/2 macro and keyframes/1 reference.
  """
  use LiveStyle.TestCase

  defmodule AnimationsModule do
    use LiveStyle

    keyframes(:spin,
      from: [transform: "rotate(0deg)"],
      to: [transform: "rotate(360deg)"]
    )

    keyframes(:fade_in,
      "0%": [opacity: "0"],
      "100%": [opacity: "1"]
    )

    keyframes(:bounce,
      "0%": [transform: "translateY(0)"],
      "50%": [transform: "translateY(-20px)"],
      "100%": [transform: "translateY(0)"]
    )

    class(:spinner,
      animation_name: keyframes(:spin),
      animation_duration: "1s",
      animation_iteration_count: "infinite"
    )
  end

  defmodule ConsumerModule do
    use LiveStyle

    class(:fade_element,
      animation_name: keyframes({LiveStyle.KeyframesTest.AnimationsModule, :fade_in}),
      animation_duration: "0.3s"
    )
  end

  describe "keyframes definition" do
    test "generates @keyframes CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@keyframes"
    end

    test "generates from/to keyframes" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "from"
      assert css =~ "to"
      assert css =~ "rotate(0deg)"
      assert css =~ "rotate(360deg)"
    end

    test "generates percentage keyframes" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "0%"
      assert css =~ "100%"
      assert css =~ "opacity:0"
      assert css =~ "opacity:1"
    end

    test "generates multi-step keyframes" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "50%"
      assert css =~ "translateY(-20px)"
    end
  end

  describe "keyframes reference" do
    test "local keyframes reference in animation-name" do
      css = LiveStyle.Compiler.generate_css()
      # animation-name should reference the hashed keyframe name
      assert css =~ ~r/animation-name:x[a-z0-9]+/
    end

    test "cross-module keyframes reference" do
      attrs = LiveStyle.Compiler.get_css(ConsumerModule, [:fade_element])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "class with keyframes returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(AnimationsModule, [:spinner])
      assert is_binary(attrs.class)
      assert attrs.style == nil
    end
  end
end
