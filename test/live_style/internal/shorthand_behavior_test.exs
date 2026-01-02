defmodule LiveStyle.Internal.ShorthandBehaviorTest do
  @moduledoc """
  Tests for the ShorthandBehavior module internals.

  These tests verify shorthand expansion with the current compile-time config.
  The config value tested is:
  - shorthand_behavior: :accept_shorthands (default)

  Available behaviors:
  - :accept_shorthands - Keep shorthands as-is (default, matches StyleX)
  - :flatten_shorthands - Expand shorthands to longhands
  - :forbid_shorthands - Forbid disallowed shorthands (border, background, etc.)

  Note: Property names are CSS strings (e.g., "margin"), not atoms.
  """
  use LiveStyle.TestCase

  alias LiveStyle.ShorthandBehavior

  describe "backend/0" do
    test "returns configured behavior module and options" do
      {module, opts} = ShorthandBehavior.backend()
      assert is_atom(module)
      assert is_list(opts)
    end

    test "default is AcceptShorthands" do
      {module, _opts} = ShorthandBehavior.backend()
      assert module == LiveStyle.ShorthandBehavior.AcceptShorthands
    end
  end

  describe "AcceptShorthands behavior (default)" do
    test "keeps margin shorthand as-is" do
      module = LiveStyle.ShorthandBehavior.AcceptShorthands
      result = module.expand_declaration("margin", "10px")
      assert result == [{"margin", "10px"}]
    end

    test "keeps padding shorthand as-is" do
      module = LiveStyle.ShorthandBehavior.AcceptShorthands
      result = module.expand_declaration("padding", "10px 20px")
      assert result == [{"padding", "10px 20px"}]
    end

    test "keeps border shorthand as-is" do
      module = LiveStyle.ShorthandBehavior.AcceptShorthands
      # Note: AcceptShorthands keeps shorthands, but may expand to longhands
      # for properties that need cascade control
      result = module.expand_declaration("border", "1px solid black")
      # Border is kept as shorthand
      assert {"border", "1px solid black"} in result
    end
  end

  describe "FlattenShorthands behavior" do
    test "expands margin to longhands" do
      module = LiveStyle.ShorthandBehavior.FlattenShorthands
      result = module.expand_declaration("margin", "10px")
      # Should expand to margin-top, margin-right, margin-bottom, margin-left
      props = Enum.map(result, fn {prop, _} -> prop end)
      assert "margin-top" in props
      assert "margin-right" in props
      assert "margin-bottom" in props
      assert "margin-left" in props
    end

    test "expands padding to longhands" do
      module = LiveStyle.ShorthandBehavior.FlattenShorthands
      result = module.expand_declaration("padding", "10px 20px")
      props = Enum.map(result, fn {prop, _} -> prop end)
      assert "padding-top" in props
      assert "padding-right" in props
      assert "padding-bottom" in props
      assert "padding-left" in props
    end

    test "parses multi-value shorthands correctly" do
      module = LiveStyle.ShorthandBehavior.FlattenShorthands
      result = module.expand_declaration("padding", "10px 20px")
      # 2-value syntax: vertical horizontal
      assert {"padding-top", "10px"} in result
      assert {"padding-right", "20px"} in result
      assert {"padding-bottom", "10px"} in result
      assert {"padding-left", "20px"} in result
    end

    test "passes through non-shorthand properties" do
      module = LiveStyle.ShorthandBehavior.FlattenShorthands
      result = module.expand_declaration("color", "red")
      assert result == [{"color", "red"}]
    end
  end

  describe "ForbidShorthands behavior" do
    # Note: ForbidShorthands only forbids *disallowed* shorthands like border,
    # background, animation, etc. Regular shorthands like margin/padding pass through.

    test "raises on border shorthand (disallowed)" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands

      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        module.expand_declaration("border", "1px solid black")
      end
    end

    test "raises on background shorthand (disallowed)" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands

      assert_raise ArgumentError, ~r/'background' is not supported/, fn ->
        module.expand_declaration("background", "red")
      end
    end

    test "raises on animation shorthand (disallowed)" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands

      assert_raise ArgumentError, ~r/'animation' is not supported/, fn ->
        module.expand_declaration("animation", "fade 1s")
      end
    end

    test "allows margin shorthand (not in disallowed list)" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands
      result = module.expand_declaration("margin", "10px")
      assert result == [{"margin", "10px"}]
    end

    test "allows padding shorthand (not in disallowed list)" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands
      result = module.expand_declaration("padding", "10px")
      assert result == [{"padding", "10px"}]
    end

    test "allows non-shorthand properties" do
      module = LiveStyle.ShorthandBehavior.ForbidShorthands
      result = module.expand_declaration("color", "red")
      assert result == [{"color", "red"}]
    end
  end
end
