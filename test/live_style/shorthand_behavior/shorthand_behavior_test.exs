defmodule LiveStyle.ShorthandBehaviorTest do
  @moduledoc """
  Tests for the three shorthand expansion behaviors:
  - :accept_shorthands (default) - Keeps shorthands, filters nil expansions
  - :flatten_shorthands - Expands shorthands to their longhand equivalents
  - :forbid_shorthands - Forbids disallowed shorthand properties at compile time

  Property keys are CSS strings (e.g., "margin-top" not :margin_top).
  """

  use LiveStyle.TestCase

  alias LiveStyle.ShorthandBehavior
  alias LiveStyle.ShorthandBehavior.{AcceptShorthands, FlattenShorthands, ForbidShorthands}

  # Common options passed to behavior functions
  @opts ShorthandBehavior.opts()

  describe "AcceptShorthands behavior" do
    test "passes through simple properties unchanged" do
      result = AcceptShorthands.expand_declaration("display", "flex", @opts)
      assert result == [{"display", "flex"}]
    end

    test "keeps shorthand, filters out nil expansion values" do
      # expand_declaration returns [{"margin", value}, {"margin-top", nil}, ...]
      # AcceptShorthands behavior filters out nils, keeping only the shorthand
      result = AcceptShorthands.expand_declaration("margin", "10px", @opts)
      assert result == [{"margin", "10px"}]
    end

    test "properties without expansion pass through" do
      result = AcceptShorthands.expand_declaration("color", "red", @opts)
      assert result == [{"color", "red"}]
    end
  end

  describe "FlattenShorthands behavior" do
    test "passes through simple properties unchanged" do
      result = FlattenShorthands.expand_declaration("display", "flex", @opts)
      assert result == [{"display", "flex"}]
    end

    test "expands margin shorthand to longhands" do
      result = FlattenShorthands.expand_declaration("margin", "10px 20px", @opts)

      assert length(result) == 4
      assert {"margin-top", "10px"} in result
      assert {"margin-right", "20px"} in result
      assert {"margin-bottom", "10px"} in result
      assert {"margin-left", "20px"} in result
    end

    test "expands border-radius shorthand" do
      result = FlattenShorthands.expand_declaration("border-radius", "4px 8px", @opts)

      assert {"border-top-left-radius", "4px"} in result
      assert {"border-top-right-radius", "8px"} in result
      assert {"border-bottom-right-radius", "4px"} in result
      assert {"border-bottom-left-radius", "8px"} in result
    end

    test "expands gap shorthand" do
      result = FlattenShorthands.expand_declaration("gap", "10px 20px", @opts)

      assert {"row-gap", "10px"} in result
      assert {"column-gap", "20px"} in result
    end

    test "handles conditional values with expansion" do
      conditions = %{
        :default => "10px 20px",
        "@media (min-width: 768px)" => "20px 40px"
      }

      result = FlattenShorthands.expand_shorthand_conditions("margin", conditions, @opts)

      # Should have 4 longhand properties
      props = Enum.map(result, fn {k, _} -> k end)
      assert "margin-top" in props
      assert "margin-right" in props
      assert "margin-bottom" in props
      assert "margin-left" in props

      # Each property should have both conditions as a sorted list
      margin_top = Enum.find(result, fn {k, _} -> k == "margin-top" end)
      {_, margin_top_conditions} = margin_top
      assert is_list(margin_top_conditions)
      assert List.keyfind(margin_top_conditions, :default, 0) != nil
      assert List.keyfind(margin_top_conditions, "@media (min-width: 768px)", 0) != nil
    end
  end

  describe "ForbidShorthands behavior" do
    test "passes through simple properties unchanged" do
      result = ForbidShorthands.expand_declaration("display", "flex", @opts)
      assert result == [{"display", "flex"}]
    end

    test "passes through allowed shorthands (margin is allowed)" do
      # margin is not in disallowed list
      result = ForbidShorthands.expand_declaration("margin", "10px", @opts)
      assert result == [{"margin", "10px"}]
    end

    test "forbids disallowed shorthand: border" do
      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        ForbidShorthands.expand_declaration("border", "1px solid black", @opts)
      end
    end

    test "forbids disallowed shorthand: background" do
      assert_raise ArgumentError, ~r/'background' is not supported/, fn ->
        ForbidShorthands.expand_declaration("background", "red", @opts)
      end
    end

    test "forbids disallowed shorthand: animation" do
      assert_raise ArgumentError, ~r/'animation' is not supported/, fn ->
        ForbidShorthands.expand_declaration("animation", "spin 1s infinite", @opts)
      end
    end

    test "forbids disallowed shorthand: border-top" do
      assert_raise ArgumentError, ~r/'border-top' is not supported/, fn ->
        ForbidShorthands.expand_declaration("border-top", "1px solid black", @opts)
      end
    end

    test "forbids disallowed shorthand: border-inline" do
      assert_raise ArgumentError, ~r/'border-inline' is not supported/, fn ->
        ForbidShorthands.expand_declaration("border-inline", "1px solid black", @opts)
      end
    end

    test "forbids disallowed shorthand in conditions" do
      conditions = [default: "1px solid black"]

      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        ForbidShorthands.expand_shorthand_conditions("border", conditions, @opts)
      end
    end

    test "provides helpful suggestions for disallowed shorthands" do
      error =
        assert_raise ArgumentError, fn ->
          ForbidShorthands.expand_declaration("border", "1px solid black", @opts)
        end

      assert error.message =~ "border-width"
      assert error.message =~ "border-style"
      assert error.message =~ "border-color"
    end
  end
end
