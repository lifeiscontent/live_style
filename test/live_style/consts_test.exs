defmodule LiveStyle.ConstsTest do
  @moduledoc """
  Tests for the consts/1 macro and const/1 reference.
  """
  use LiveStyle.TestCase

  defmodule ConstantsModule do
    use LiveStyle

    consts(
      breakpoint_sm: "@media (max-width: 640px)",
      breakpoint_lg: "@media (min-width: 1025px)",
      z_modal: "50",
      z_tooltip: "100"
    )
  end

  defmodule ConsumerModule do
    use LiveStyle

    class(:responsive,
      font_size: [
        {:default, "16px"},
        {const({LiveStyle.ConstsTest.ConstantsModule, :breakpoint_sm}), "14px"}
      ]
    )

    class(:modal,
      z_index: const({LiveStyle.ConstsTest.ConstantsModule, :z_modal})
    )
  end

  defmodule LocalConstsModule do
    use LiveStyle

    consts(small_breakpoint: "@media (max-width: 480px)")

    class(:local_responsive,
      padding: [
        {:default, "16px"},
        {const(:small_breakpoint), "8px"}
      ]
    )
  end

  describe "consts definition" do
    test "consts do not generate CSS output" do
      css = LiveStyle.Compiler.generate_css()
      # Constants should NOT appear in CSS - they are compile-time only
      # The actual values are inlined where used
      refute css =~ "breakpoint_sm"
      refute css =~ "breakpoint_lg"
    end

    test "const values are accessible via ref" do
      value = LiveStyle.Consts.ref({ConstantsModule, :z_modal})
      assert value == "50"
    end
  end

  describe "const references in classes" do
    test "const as media query condition generates CSS" do
      css = LiveStyle.Compiler.generate_css()
      # The media query value should be inlined
      assert css =~ "@media (max-width: 640px)"
      assert css =~ "font-size:14px"
    end

    test "const as property value generates CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "z-index:50"
    end

    test "class using const returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(ConsumerModule, [:modal])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  describe "local const references" do
    test "local const reference works in same module" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media (max-width: 480px)"
      assert css =~ "padding:8px"
    end
  end
end
