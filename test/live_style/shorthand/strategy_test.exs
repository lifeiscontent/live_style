defmodule LiveStyle.Shorthand.StrategyTest do
  @moduledoc """
  Tests for the three shorthand expansion strategies:
  - :keep_shorthands (default) - Keeps shorthands, rejects nil expansions
  - :expand_to_longhands - Expands shorthands to their longhand equivalents
  - :reject_shorthands - Rejects disallowed shorthand properties at compile time
  """

  use LiveStyle.TestCase, async: true

  alias LiveStyle.Shorthand.Strategy
  alias LiveStyle.Shorthand.Strategy.{KeepShorthands, ExpandToLonghands, RejectShorthands}

  # Common options passed to strategy functions
  @opts Strategy.opts()

  describe "KeepShorthands strategy" do
    test "passes through simple properties unchanged" do
      result = KeepShorthands.expand_declaration(:display, "flex", @opts)
      assert result == [{:display, "flex"}]
    end

    test "keeps shorthand, filters out nil expansion values" do
      # expand_margin returns [{:margin, value}, {:margin_top, nil}, ...]
      # KeepShorthands strategy filters out nils, keeping only the shorthand
      result = KeepShorthands.expand_declaration(:margin, "10px", @opts)
      assert result == [{:margin, "10px"}]
    end

    test "properties without expansion pass through" do
      result = KeepShorthands.expand_declaration(:color, "red", @opts)
      assert result == [{:color, "red"}]
    end
  end

  describe "ExpandToLonghands strategy" do
    test "passes through simple properties unchanged" do
      result = ExpandToLonghands.expand_declaration(:display, "flex", @opts)
      assert result == [{:display, "flex"}]
    end

    test "expands margin shorthand to longhands" do
      result = ExpandToLonghands.expand_declaration(:margin, "10px 20px", @opts)

      assert length(result) == 4
      assert {:margin_top, "10px"} in result
      assert {:margin_right, "20px"} in result
      assert {:margin_bottom, "10px"} in result
      assert {:margin_left, "20px"} in result
    end

    test "expands border-radius shorthand" do
      result = ExpandToLonghands.expand_declaration(:border_radius, "4px 8px", @opts)

      assert {:border_top_left_radius, "4px"} in result
      assert {:border_top_right_radius, "8px"} in result
      assert {:border_bottom_right_radius, "4px"} in result
      assert {:border_bottom_left_radius, "8px"} in result
    end

    test "expands gap shorthand" do
      result = ExpandToLonghands.expand_declaration(:gap, "10px 20px", @opts)

      assert {:row_gap, "10px"} in result
      assert {:column_gap, "20px"} in result
    end

    test "handles conditional values with expansion" do
      conditions = %{
        :default => "10px 20px",
        "@media (min-width: 768px)" => "20px 40px"
      }

      result = ExpandToLonghands.expand_shorthand_conditions(:margin, "margin", conditions, @opts)

      # Should have 4 longhand properties
      props = Enum.map(result, fn {k, _} -> k end)
      assert :margin_top in props
      assert :margin_right in props
      assert :margin_bottom in props
      assert :margin_left in props

      # Each property should have both conditions
      margin_top = Enum.find(result, fn {k, _} -> k == :margin_top end)
      {_, margin_top_conditions} = margin_top
      assert Map.has_key?(margin_top_conditions, :default)
      assert Map.has_key?(margin_top_conditions, "@media (min-width: 768px)")
    end
  end

  describe "RejectShorthands strategy" do
    test "passes through simple properties unchanged" do
      result = RejectShorthands.expand_declaration(:display, "flex", @opts)
      assert result == [{:display, "flex"}]
    end

    test "passes through allowed shorthands (margin is allowed)" do
      # margin is not in disallowed list
      result = RejectShorthands.expand_declaration(:margin, "10px", @opts)
      assert result == [{:margin, "10px"}]
    end

    test "rejects disallowed shorthand: border" do
      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        RejectShorthands.expand_declaration(:border, "1px solid black", @opts)
      end
    end

    test "rejects disallowed shorthand: background" do
      assert_raise ArgumentError, ~r/'background' is not supported/, fn ->
        RejectShorthands.expand_declaration(:background, "red", @opts)
      end
    end

    test "rejects disallowed shorthand: animation" do
      assert_raise ArgumentError, ~r/'animation' is not supported/, fn ->
        RejectShorthands.expand_declaration(:animation, "spin 1s infinite", @opts)
      end
    end

    test "rejects disallowed shorthand: border-top" do
      assert_raise ArgumentError, ~r/'border-top' is not supported/, fn ->
        RejectShorthands.expand_declaration(:border_top, "1px solid black", @opts)
      end
    end

    test "rejects disallowed shorthand: border-inline" do
      assert_raise ArgumentError, ~r/'border-inline' is not supported/, fn ->
        RejectShorthands.expand_declaration(:border_inline, "1px solid black", @opts)
      end
    end

    test "rejects disallowed shorthand in conditions" do
      conditions = %{:default => "1px solid black"}

      assert_raise ArgumentError, ~r/'border' is not supported/, fn ->
        RejectShorthands.expand_shorthand_conditions(:border, "border", conditions, @opts)
      end
    end

    test "provides helpful suggestions for disallowed shorthands" do
      error =
        assert_raise ArgumentError, fn ->
          RejectShorthands.expand_declaration(:border, "1px solid black", @opts)
        end

      assert error.message =~ "border-width"
      assert error.message =~ "border-style"
      assert error.message =~ "border-color"
    end
  end

  describe "Backend dispatch" do
    test "backend/0 returns correct tuple for :keep_shorthands" do
      LiveStyle.Config.put(:shorthand_strategy, :keep_shorthands)
      assert Strategy.backend() == {KeepShorthands, []}
    end

    test "backend/0 returns correct tuple for :expand_to_longhands" do
      LiveStyle.Config.put(:shorthand_strategy, :expand_to_longhands)
      assert Strategy.backend() == {ExpandToLonghands, []}
    end

    test "backend/0 returns correct tuple for :reject_shorthands" do
      LiveStyle.Config.put(:shorthand_strategy, :reject_shorthands)
      assert Strategy.backend() == {RejectShorthands, []}
    end

    test "backend_module/0 returns just the module" do
      LiveStyle.Config.put(:shorthand_strategy, :keep_shorthands)
      assert Strategy.backend_module() == KeepShorthands

      LiveStyle.Config.put(:shorthand_strategy, :expand_to_longhands)
      assert Strategy.backend_module() == ExpandToLonghands
    end

    test "backend/0 accepts module directly" do
      LiveStyle.Config.put(:shorthand_strategy, KeepShorthands)
      assert Strategy.backend() == {KeepShorthands, []}
    end

    test "backend/0 accepts {module, opts} tuple" do
      LiveStyle.Config.put(:shorthand_strategy, {KeepShorthands, some_opt: true})
      assert Strategy.backend() == {KeepShorthands, some_opt: true}
    end
  end
end
