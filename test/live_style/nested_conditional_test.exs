defmodule LiveStyle.NestedConditionalTest do
  @moduledoc """
  Tests for StyleX-style nested conditional syntax.

  These tests verify that live_style supports the same nested keyword list syntax
  as StyleX's "modern" syntax for combining media queries with pseudo-classes.

  StyleX reference: packages/@stylexjs/babel-plugin/src/shared/preprocess-rules/__tests__/flatten-raw-style-obj-test.js
  """
  use LiveStyle.TestCase

  alias LiveStyle.Class.Conditional
  alias LiveStyle.Selector.Condition

  describe "StyleX modern syntax: pseudo within a media query" do
    # Corresponds to StyleX test: 'pseudo within a media query - modern syntax' (line 633-658)
    #
    # StyleX input:
    # {
    #   color: {
    #     default: 'blue',
    #     '@media (min-width: 300px)': {
    #       ':hover': 'red',
    #     },
    #   },
    # }
    #
    # StyleX output:
    # - PreRule('color', 'blue', ['color', 'default'])
    # - PreRule('color', 'red', ['color', '@media (min-width: 300px)', ':hover'])

    test "flattens to same structure as StyleX" do
      input = [
        default: "blue",
        "@media (min-width: 300px)": [
          ":hover": "red"
        ]
      ]

      result = Conditional.flatten(input, nil)

      # Should produce exactly 2 rules, matching StyleX:
      # 1. Default rule (no condition)
      # 2. Media query + hover rule (no intermediate media-query-only rule!)
      assert result == [
               {nil, "blue"},
               {"@media (min-width: 300px):hover", "red"}
             ]
    end

    test "parse_combined extracts selector and at-rule correctly" do
      assert Condition.parse_combined("@media (min-width: 300px):hover") ==
               {":hover", "@media (min-width: 300px)"}
    end
  end

  describe "StyleX modern syntax: extra deep nesting" do
    # Corresponds to StyleX test: 'extra deep, pseudo within a media query - modern syntax' (line 660-696)
    #
    # StyleX input:
    # {
    #   color: {
    #     default: 'blue',
    #     '@media (min-width: 300px)': {
    #       ':hover': {
    #         default: 'red',
    #         ':active': 'maroon',
    #       },
    #     },
    #   },
    # }
    #
    # StyleX output:
    # - PreRule('color', 'blue', [..., 'default'])
    # - PreRule('color', 'red', [..., '@media (min-width: 300px)', ':hover', 'default'])
    # - PreRule('color', 'maroon', [..., '@media (min-width: 300px)', ':hover', ':active'])

    test "flattens deeply nested conditionals same as StyleX" do
      input = [
        default: "blue",
        "@media (min-width: 300px)": [
          ":hover": [
            default: "red",
            ":active": "maroon"
          ]
        ]
      ]

      result = Conditional.flatten(input, nil)

      assert result == [
               {nil, "blue"},
               {"@media (min-width: 300px):hover", "red"},
               {"@media (min-width: 300px):hover:active", "maroon"}
             ]
    end

    test "parse_combined handles chained pseudo-classes" do
      assert Condition.parse_combined("@media (min-width: 300px):hover:active") ==
               {":hover:active", "@media (min-width: 300px)"}
    end
  end

  describe "StyleX modern syntax: with default inside media query" do
    # This is an extension that StyleX also supports - having a default value
    # inside the media query alongside conditional values.
    #
    # StyleX test: transform-stylex-create-test.js line 2340-2393

    test "flattens media query with both default and hover" do
      input = [
        default: "1rem",
        "@media (min-width: 800px)": [
          default: "2rem",
          ":hover": "2.2rem"
        ]
      ]

      result = Conditional.flatten(input, nil)

      assert result == [
               {nil, "1rem"},
               {"@media (min-width: 800px)", "2rem"},
               {"@media (min-width: 800px):hover", "2.2rem"}
             ]
    end
  end

  describe "alternative ordering: pseudo-class first, then media query" do
    # live_style also supports the reverse nesting order

    test "flattens pseudo-first nesting" do
      input = [
        default: "blue",
        ":hover": [
          default: "red",
          "@media (min-width: 300px)": "green"
        ]
      ]

      result = Conditional.flatten(input, nil)

      assert result == [
               {nil, "blue"},
               {":hover", "red"},
               {":hover@media (min-width: 300px)", "green"}
             ]
    end

    test "parse_combined handles pseudo-first ordering" do
      # Both orderings produce the same parsed result
      assert Condition.parse_combined(":hover@media (min-width: 300px)") ==
               {":hover", "@media (min-width: 300px)"}
    end
  end
end
