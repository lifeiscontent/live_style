defmodule LiveStyle.VarsTest do
  @moduledoc """
  Tests for the vars/1 macro and var/1 reference.
  """
  use LiveStyle.TestCase

  defmodule TokensModule do
    use LiveStyle

    vars(
      white: "#ffffff",
      primary: "#3b82f6",
      spacing_sm: "0.5rem"
    )
  end

  defmodule ConsumerModule do
    use LiveStyle

    class(:themed,
      color: var({LiveStyle.VarsTest.TokensModule, :white}),
      background_color: var({LiveStyle.VarsTest.TokensModule, :primary})
    )
  end

  defmodule LocalVarsModule do
    use LiveStyle

    vars(accent: "#ff0000")

    class(:local_themed,
      border_color: var(:accent)
    )
  end

  describe "vars definition" do
    test "generates :root CSS with custom properties" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ":root"
      assert css =~ "#ffffff"
      assert css =~ "#3b82f6"
      assert css =~ "0.5rem"
    end

    test "generates hashed variable names" do
      css = LiveStyle.Compiler.generate_css()
      # Variables should have hashed names like --x1abc2de
      assert css =~ ~r/--x[a-z0-9]+/
    end
  end

  describe "var references" do
    test "cross-module var reference generates var() in CSS" do
      css = LiveStyle.Compiler.generate_css()
      # The class should reference the variable with var(--hash)
      assert css =~ ~r/color:var\(--x[a-z0-9]+\)/
      assert css =~ ~r/background-color:var\(--x[a-z0-9]+\)/
    end

    test "local var reference generates var() in CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ~r/border-color:var\(--x[a-z0-9]+\)/
    end

    test "class using var returns valid class string" do
      attrs = LiveStyle.Compiler.get_css(ConsumerModule, [:themed])
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end
end
