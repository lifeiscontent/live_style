defmodule LiveStyle.Selector.ConditionTest do
  @moduledoc """
  Tests for the Selector.Condition module.

  This module parses combined StyleX condition selectors, separating
  pseudo-selectors from at-rules.
  """
  use ExUnit.Case, async: true

  alias LiveStyle.Selector.Condition

  describe "parse_combined/1" do
    test "simple pseudo-class returns {selector, nil}" do
      assert Condition.parse_combined(":hover") == {":hover", nil}
    end

    test "simple at-rule returns {nil, at_rule}" do
      assert Condition.parse_combined("@media (min-width: 800px)") ==
               {nil, "@media (min-width: 800px)"}
    end

    test "at-rule followed by pseudo-class" do
      assert Condition.parse_combined("@media (min-width: 800px):hover") ==
               {":hover", "@media (min-width: 800px)"}
    end

    test "multiple at-rules followed by pseudo-class" do
      result =
        Condition.parse_combined("@media (min-width: 800px)@supports (color: oklch(0 0 0)):hover")

      assert result == {":hover", "@media (min-width: 800px)@supports (color: oklch(0 0 0))"}
    end

    test "pseudo-class followed by at-rule" do
      assert Condition.parse_combined(":not([data-theme])@media (prefers-color-scheme: dark)") ==
               {":not([data-theme])", "@media (prefers-color-scheme: dark)"}
    end

    test "complex pseudo-selector followed by at-rule" do
      assert Condition.parse_combined(":where([data-theme=\"dark\"])@media print") ==
               {":where([data-theme=\"dark\"])", "@media print"}
    end

    test ":hover followed by media query" do
      assert Condition.parse_combined(":hover@media (min-width: 768px)") ==
               {":hover", "@media (min-width: 768px)"}
    end

    test "pseudo-class with no at-rule" do
      assert Condition.parse_combined(":focus:visible") == {":focus:visible", nil}
    end

    test "contextual selector with no at-rule" do
      assert Condition.parse_combined(":where(.dark-mode)") == {":where(.dark-mode)", nil}
    end
  end
end
