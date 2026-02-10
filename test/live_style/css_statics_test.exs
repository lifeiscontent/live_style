defmodule LiveStyle.CssStaticsTest do
  @moduledoc """
  Tests for compile-time css() macro optimization.

  Phoenix LiveView PR #4145 expands root attr macros in the tag engine.
  When css() returns a literal list of {:class, [class_string]} tuples,
  the class string ends up in Rendered.static instead of being dynamic.
  """
  use LiveStyle.TestCase

  defmodule Tokens do
    use LiveStyle

    vars(
      primary: "#3b82f6",
      white: "#ffffff"
    )
  end

  defmodule SharedStyles do
    use LiveStyle

    class(:shared_base,
      display: "block",
      margin: "0"
    )

    class(:shared_highlight,
      background_color: "yellow"
    )
  end

  defmodule Transitions do
    use LiveStyle

    keyframes(:scale_in,
      from: [opacity: "0", transform: "scale(0.8)"],
      to: [opacity: "1", transform: "scale(1)"]
    )

    keyframes(:scale_out,
      from: [opacity: "1", transform: "scale(1)"],
      to: [opacity: "0", transform: "scale(0.8)"]
    )

    view_transition_class(:card,
      old: [
        animation_name: keyframes(:scale_out),
        animation_duration: "200ms"
      ],
      new: [
        animation_name: keyframes(:scale_in),
        animation_duration: "200ms"
      ]
    )
  end

  defmodule StaticStyles do
    use LiveStyle

    class(:button,
      display: "flex",
      padding: "8px 16px"
    )

    class(:primary,
      background_color: "blue",
      color: "white"
    )

    class(:secondary,
      background_color: "gray",
      color: "black"
    )

    class(:with_var,
      color: var({Tokens, :primary})
    )

    class(:with_hover,
      color: [
        default: "blue",
        ":hover": "darkblue"
      ]
    )

    class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)

    # --- css() calls that should be compile-time ---

    def single_ref, do: css(:button)
    def list_refs, do: css([:button, :primary])
    def single_hover, do: css(:with_hover)
    def cross_module_list, do: css([{SharedStyles, :shared_base}, :button])
    def dynamic_bare, do: css(:dynamic_opacity)
    def merged_overlap, do: css([:primary, :secondary])
    def static_with_style_opts, do: css([:button], style: [opacity: "0.5"])

    def static_with_view_transition do
      css([:button],
        style: [
          view_transition_class: view_transition_class({Transitions, :card}),
          view_transition_name: "my-card"
        ]
      )
    end

    def static_dynamic_with_args do
      css([{:dynamic_opacity, 0.5}])
    end

    # --- css() calls with branch optimization (compile-time branches) ---

    def conditional_ref(active) do
      css([:button, active && :primary])
    end

    def if_else_ref(selected) do
      css([if(selected, do: :primary, else: :secondary)])
    end

    def if_else_with_base(selected) do
      css([:button, if(selected, do: :primary, else: :secondary)])
    end

    def case_ref(variant) do
      css([
        case variant do
          :primary -> :primary
          :secondary -> :secondary
          _ -> :button
        end
      ])
    end

    def case_with_base(variant) do
      css([
        :button,
        case variant do
          :primary -> :primary
          :secondary -> :secondary
        end
      ])
    end

    def cond_ref(size) do
      css([
        cond do
          size > 100 -> :primary
          size > 50 -> :secondary
          true -> :button
        end
      ])
    end

    # --- css() calls that must be runtime ---

    def dynamic_with_args(opacity) do
      css([{:dynamic_opacity, opacity}])
    end

    def with_dynamic_style_opts(opacity) do
      css([:button], style: [opacity: opacity])
    end

    def two_conditionals(a, b) do
      css([a && :button, b && :primary])
    end

    def case_and_conditional(variant, full_width) do
      css([
        :button,
        case variant do
          :primary -> :primary
          :secondary -> :secondary
        end,
        full_width && :with_hover
      ])
    end
  end

  describe "css/1 single atom returns literal list" do
    test "returns list of {:class, [class_string]} tuples" do
      result = StaticStyles.single_ref()
      assert is_list(result)
      assert [{:class, [class_string]}] = result
      assert is_binary(class_string)
      assert class_string != ""
    end

    test "class string matches module's class_strings" do
      [{:class, [class_string]}] = StaticStyles.single_ref()
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:button)
      assert class_string == expected
    end

    test "hover class contains all condition classes" do
      [{:class, [class_string]}] = StaticStyles.single_hover()
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:with_hover)
      assert class_string == expected
      # Two classes: default color + :hover color
      assert length(String.split(class_string)) == 2
    end

    test "dynamic class bare atom returns class string" do
      [{:class, [class_string]}] = StaticStyles.dynamic_bare()
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:dynamic_opacity)
      assert class_string == expected
    end
  end

  describe "css/1 list of static atoms returns literal list" do
    test "returns merged class string" do
      result = StaticStyles.list_refs()
      assert [{:class, [class_string]}] = result
      assert is_binary(class_string)
    end

    test "merged class string includes classes from all refs (no overlap)" do
      [{:class, [merged]}] = StaticStyles.list_refs()

      # :button has display + padding, :primary has background-color + color
      # No property overlap, so all 4 classes should be present
      classes = String.split(merged)
      assert length(classes) == 4
    end

    test "last-wins merging removes overridden property classes" do
      [{:class, [merged]}] = StaticStyles.merged_overlap()

      # :primary has background-color + color, :secondary has background-color + color
      # Both properties overlap, so only :secondary's classes should win
      # Result: secondary's bg-color + secondary's color = 2 unique property winners
      # Plus primary's bg-color is overridden
      merged_classes = String.split(merged)

      # Should have exactly 2 classes (one per unique property, both from :secondary)
      assert length(merged_classes) == 2

      # The classes should match :secondary's classes (last wins)
      secondary_class_string =
        StaticStyles.__live_style__(:class_strings) |> Keyword.get(:secondary)

      secondary_classes = String.split(secondary_class_string) |> MapSet.new()
      merged_set = MapSet.new(merged_classes)

      assert merged_set == secondary_classes
    end
  end

  describe "cross-module refs in list" do
    test "resolves cross-module refs at compile time" do
      result = StaticStyles.cross_module_list()
      assert [{:class, [class_string]}] = result
      assert is_binary(class_string)
      assert class_string != ""
    end

    test "cross-module merge produces correct number of classes" do
      [{:class, [class_string]}] = StaticStyles.cross_module_list()

      # shared_base has display + margin, button has display + padding
      # display overlaps (button wins since it's last), so 3 unique properties:
      # button's display + shared_base's margin + button's padding
      classes = String.split(class_string)
      assert length(classes) == 3
    end
  end

  describe "dynamic class with static args returns literal list" do
    test "returns class and style attrs" do
      result = StaticStyles.static_dynamic_with_args()
      assert is_list(result)

      class_pair = List.keyfind(result, :class, 0)
      style_pair = List.keyfind(result, :style, 0)

      assert {:class, [class_string]} = class_pair
      assert is_binary(class_string)
      assert class_string != ""

      assert {:style, [style_string]} = style_pair
      assert is_binary(style_string)
      assert String.contains?(style_string, "0.5")
    end
  end

  describe "css/2 with static style opts returns literal list" do
    test "returns class and style attrs" do
      result = StaticStyles.static_with_style_opts()
      assert is_list(result)

      class_pair = List.keyfind(result, :class, 0)
      style_pair = List.keyfind(result, :style, 0)

      assert {:class, [class_string]} = class_pair
      assert is_binary(class_string)
      assert class_string != ""

      assert {:style, [style_string]} = style_pair
      assert is_binary(style_string)
      assert String.contains?(style_string, "opacity")
      assert String.contains?(style_string, "0.5")
    end

    test "view_transition_class macro in style opts is static" do
      result = StaticStyles.static_with_view_transition()
      assert is_list(result)

      class_pair = List.keyfind(result, :class, 0)
      style_pair = List.keyfind(result, :style, 0)

      assert {:class, [class_string]} = class_pair
      assert is_binary(class_string)
      assert class_string != ""

      assert {:style, [style_string]} = style_pair
      assert is_binary(style_string)
      assert String.contains?(style_string, "view-transition-class:")
      assert String.contains?(style_string, "view-transition-name: my-card")
    end
  end

  describe "branch optimization for && conditionals" do
    test "truthy branch returns merged class string" do
      result = StaticStyles.conditional_ref(true)
      assert is_list(result)
      assert [{:class, [class_string]}] = result
      assert is_binary(class_string)
      # :button has display + padding, :primary has background-color + color = 4 classes
      assert length(String.split(class_string)) == 4
    end

    test "falsy branch returns only base classes" do
      result = StaticStyles.conditional_ref(false)
      assert is_list(result)
      assert [{:class, [class_string]}] = result
      assert is_binary(class_string)
      # Only :button (display + padding) = 2 classes
      assert length(String.split(class_string)) == 2
    end
  end

  describe "branch optimization for if/else" do
    test "truthy branch returns do-branch classes" do
      result = StaticStyles.if_else_ref(true)
      assert is_list(result)
      assert [{:class, [class_string]}] = result

      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:primary)
      assert MapSet.new(String.split(class_string)) == MapSet.new(String.split(expected))
    end

    test "falsy branch returns else-branch classes" do
      result = StaticStyles.if_else_ref(false)
      assert is_list(result)
      assert [{:class, [class_string]}] = result

      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:secondary)
      assert MapSet.new(String.split(class_string)) == MapSet.new(String.split(expected))
    end

    test "if/else with base class merges correctly on truthy" do
      result = StaticStyles.if_else_with_base(true)
      assert [{:class, [class_string]}] = result
      # :button (display + padding) + :primary (background-color + color) = 4 classes
      assert length(String.split(class_string)) == 4
    end

    test "if/else with base class merges correctly on falsy" do
      result = StaticStyles.if_else_with_base(false)
      assert [{:class, [class_string]}] = result
      # :button (display + padding) + :secondary (background-color + color) = 4 classes
      assert length(String.split(class_string)) == 4
    end
  end

  describe "branch optimization for case" do
    test "each branch returns correct pre-computed classes" do
      primary_result = StaticStyles.case_ref(:primary)
      assert [{:class, [primary_class]}] = primary_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:primary)
      assert MapSet.new(String.split(primary_class)) == MapSet.new(String.split(expected))

      secondary_result = StaticStyles.case_ref(:secondary)
      assert [{:class, [secondary_class]}] = secondary_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:secondary)
      assert MapSet.new(String.split(secondary_class)) == MapSet.new(String.split(expected))

      default_result = StaticStyles.case_ref(:unknown)
      assert [{:class, [default_class]}] = default_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:button)
      assert MapSet.new(String.split(default_class)) == MapSet.new(String.split(expected))
    end

    test "case with base class merges correctly" do
      result = StaticStyles.case_with_base(:primary)
      assert [{:class, [class_string]}] = result
      # :button (display + padding) + :primary (background-color + color) = 4 classes
      assert length(String.split(class_string)) == 4
    end
  end

  describe "branch optimization for cond" do
    test "each branch returns correct pre-computed classes" do
      large_result = StaticStyles.cond_ref(150)
      assert [{:class, [class_string]}] = large_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:primary)
      assert MapSet.new(String.split(class_string)) == MapSet.new(String.split(expected))

      medium_result = StaticStyles.cond_ref(75)
      assert [{:class, [class_string]}] = medium_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:secondary)
      assert MapSet.new(String.split(class_string)) == MapSet.new(String.split(expected))

      small_result = StaticStyles.cond_ref(10)
      assert [{:class, [class_string]}] = small_result
      expected = StaticStyles.__live_style__(:class_strings) |> Keyword.get(:button)
      assert MapSet.new(String.split(class_string)) == MapSet.new(String.split(expected))
    end
  end

  describe "runtime fallback for dynamic refs" do
    test "dynamic class with args uses runtime" do
      result = StaticStyles.dynamic_with_args("0.5")
      assert %LiveStyle.Attrs{} = result
      assert is_binary(result.style)
      assert String.contains?(result.style, "0.5")
    end

    test "css/2 with dynamic style opts uses runtime" do
      result = StaticStyles.with_dynamic_style_opts("0.5")
      assert %LiveStyle.Attrs{} = result
      assert String.contains?(result.style, "opacity")
    end

    test "multiple && conditionals are branch-optimized" do
      # Both true: :button + :primary = 4 classes
      result = StaticStyles.two_conditionals(true, true)
      assert [{:class, [class_string]}] = result
      assert length(String.split(class_string)) == 4

      # First true only: just :button = 2 classes
      result = StaticStyles.two_conditionals(true, false)
      assert [{:class, [class_string]}] = result
      assert length(String.split(class_string)) == 2

      # Second true only: just :primary = 2 classes
      result = StaticStyles.two_conditionals(false, true)
      assert [{:class, [class_string]}] = result
      assert length(String.split(class_string)) == 2

      # Neither: empty
      result = StaticStyles.two_conditionals(false, false)
      assert result == []
    end

    test "case + && multi-conditional is branch-optimized" do
      # :button + :primary + :with_hover
      result = StaticStyles.case_and_conditional(:primary, true)
      assert [{:class, [class_string]}] = result
      # button(display+padding) + primary(bg+color) + with_hover(2 color conditions)
      # display, padding, bg-color, color(last wins from with_hover's 2 classes)
      assert length(String.split(class_string)) > 2

      # :button + :secondary, no with_hover
      result = StaticStyles.case_and_conditional(:secondary, false)
      assert [{:class, [class_string]}] = result
      assert length(String.split(class_string)) > 2
    end
  end

  describe "forward reference fallback" do
    test "undefined single ref falls back to runtime" do
      [{module, _}] =
        Code.compile_string("""
        defmodule LiveStyle.CssStaticsTest.ForwardSingle do
          use LiveStyle
          def test_fn, do: css(:nonexistent)
        end
        """)

      result = module.test_fn()
      # Falls back to runtime — returns Attrs with empty class
      assert %LiveStyle.Attrs{} = result
    end

    test "undefined ref in list falls back to runtime" do
      [{module, _}] =
        Code.compile_string("""
        defmodule LiveStyle.CssStaticsTest.ForwardInList do
          use LiveStyle
          class :exists, display: "flex"
          def test_fn, do: css([:exists, :nonexistent])
        end
        """)

      result = module.test_fn()
      # Falls back to runtime because :nonexistent isn't defined yet
      assert %LiveStyle.Attrs{} = result
    end

    test "class defined after css() falls back to runtime" do
      [{module, _}] =
        Code.compile_string("""
        defmodule LiveStyle.CssStaticsTest.ForwardRef do
          use LiveStyle
          def test_fn, do: css(:later_class)
          class :later_class, display: "flex"
        end
        """)

      result = module.test_fn()
      assert %LiveStyle.Attrs{} = result
      assert is_binary(result.class)
    end
  end
end
