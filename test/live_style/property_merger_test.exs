defmodule LiveStyle.PropertyMergerTest do
  @moduledoc """
  Tests for LiveStyle.Runtime.PropertyMerger.

  These tests verify StyleX/styleq-compatible property merging behavior where:
  - Each property key is completely independent
  - Last value wins only for the exact same key
  - "default" condition uses just the property name (so simple "color" and conditional
    "color: [default: ...]" both produce "color" key and conflict correctly)
  - Other conditions like ":hover" use "property:::hover" format
  - :__unset__ removes only the exact property key
  """
  use ExUnit.Case, async: true

  alias LiveStyle.Runtime.PropertyMerger

  # Helper to chain merges correctly (prop_classes first, accumulator second)
  defp chain_merge(acc, prop_classes), do: PropertyMerger.merge(prop_classes, acc)

  describe "basic merging (StyleX parity)" do
    test "empty list returns accumulator unchanged" do
      acc = [{"color", "x123"}]
      assert PropertyMerger.merge([], acc) == acc
    end

    test "merges into empty accumulator" do
      props = [{"color", "x123"}, {"background-color", "x456"}]
      result = PropertyMerger.merge(props, [])

      assert {"color", "x123"} in result
      assert {"background-color", "x456"} in result
    end

    test "last value wins for exact same key" do
      # styleq test: "dedupes class names for the same key"
      props1 = [{"backgroundColor", "backgroundColor-a"}]
      props2 = [{"backgroundColor", "backgroundColor-b"}]

      result =
        []
        |> chain_merge(props1)
        |> chain_merge(props2)

      classes = PropertyMerger.to_class_list(result)
      assert classes == ["backgroundColor-b"]
    end

    test "different properties coexist" do
      props = [{"color", "x1"}, {"background-color", "x2"}, {"padding", "x3"}]
      result = PropertyMerger.merge(props, [])

      assert length(result) == 3
      classes = PropertyMerger.to_class_list(result)
      assert "x1" in classes
      assert "x2" in classes
      assert "x3" in classes
    end

    test "combines different class names in order" do
      # styleq test: "combines different class names in order"
      a = [{"a", "a"}, {":focus$aa", "focus$aa"}]
      b = [{"b", "b"}]
      c = [{"c", "c"}, {":focus$cc", "focus$cc"}]

      result =
        []
        |> chain_merge(a)
        |> chain_merge(b)
        |> chain_merge(c)

      # All classes should be present since they're all different keys
      classes = PropertyMerger.to_class_list(result)
      assert "a" in classes
      assert "focus$aa" in classes
      assert "b" in classes
      assert "c" in classes
      assert "focus$cc" in classes
    end
  end

  describe "StyleX-compatible property merging" do
    test "simple property overrides conditional default (same key)" do
      # In StyleX: "color" from simple and "color" from conditional default are SAME KEY
      # The default condition produces just the property name
      simple = [{"color", "color-class"}]
      # Note: In actual compiled output, default produces "color" not "color::default"
      conditional = [{"color", "default-class"}, {"color:::hover", "hover-class"}]

      result =
        []
        |> chain_merge(simple)
        |> chain_merge(conditional)

      classes = PropertyMerger.to_class_list(result)

      # Simple "color" is overridden by conditional "color" (same key, last wins)
      refute "color-class" in classes
      assert "default-class" in classes
      # :hover is independent key, coexists
      assert "hover-class" in classes
    end

    test "different pseudo-class conditions coexist" do
      # Different conditions are different keys
      props = [
        {"color", "default-class"},
        {"color:::hover", "hover-class"},
        {"color:::focus", "focus-class"}
      ]

      result = PropertyMerger.merge(props, [])
      classes = PropertyMerger.to_class_list(result)

      # All coexist - different keys
      assert "default-class" in classes
      assert "hover-class" in classes
      assert "focus-class" in classes
    end

    test "later conditional overrides earlier conditional with same exact key" do
      props1 = [{"color:::hover", "hover1"}]
      props2 = [{"color:::hover", "hover2"}]

      result =
        []
        |> chain_merge(props1)
        |> chain_merge(props2)

      classes = PropertyMerger.to_class_list(result)

      # Same exact key - last wins
      refute "hover1" in classes
      assert "hover2" in classes
    end
  end

  describe ":__unset__ behavior (null in StyleX)" do
    test ":__unset__ removes only exact key" do
      # styleq test: "dedupes class names with null value"
      props = [{"color", "x123"}]
      unset = [{"color", :__unset__}]

      result =
        []
        |> chain_merge(props)
        |> chain_merge(unset)

      assert PropertyMerger.to_class_list(result) == []
    end

    test ":__unset__ on base property doesn't affect pseudo-class variants" do
      # In StyleX, null on "color" doesn't affect ":hover_color"
      props = [
        {"color", "color-class"},
        {"color:::hover", "hover-class"}
      ]

      unset = [{"color", :__unset__}]

      result =
        []
        |> chain_merge(props)
        |> chain_merge(unset)

      classes = PropertyMerger.to_class_list(result)

      # Only exact "color" key is removed, pseudo-class variant remains
      refute "color-class" in classes
      assert "hover-class" in classes
    end

    test ":__unset__ on pseudo-class variant doesn't affect base property" do
      props = [
        {"color", "default-class"},
        {"color:::hover", "hover-class"}
      ]

      unset = [{"color:::hover", :__unset__}]

      result =
        []
        |> chain_merge(props)
        |> chain_merge(unset)

      classes = PropertyMerger.to_class_list(result)

      # Only exact key is removed
      assert "default-class" in classes
      refute "hover-class" in classes
    end

    test ":__unset__ doesn't affect other properties" do
      props = [
        {"color", "color-class"},
        {"background-color", "bg-class"}
      ]

      unset = [{"color", :__unset__}]

      result =
        []
        |> chain_merge(props)
        |> chain_merge(unset)

      classes = PropertyMerger.to_class_list(result)
      assert classes == ["bg-class"]
    end
  end

  describe "to_class_list/1" do
    test "filters out :__unset__ values" do
      acc = [{"color", "x123"}, {"background", :__unset__}]
      assert PropertyMerger.to_class_list(acc) == ["x123"]
    end

    test "filters out nil values" do
      acc = [{"color", "x123"}, {"background", nil}]
      assert PropertyMerger.to_class_list(acc) == ["x123"]
    end

    test "filters out empty string values" do
      acc = [{"color", "x123"}, {"background", ""}]
      assert PropertyMerger.to_class_list(acc) == ["x123"]
    end

    test "preserves order from accumulator" do
      acc = [{"a", "first"}, {"b", "second"}, {"c", "third"}]
      assert PropertyMerger.to_class_list(acc) == ["first", "second", "third"]
    end
  end

  describe "StyleX parity scenarios" do
    test "hover override only affects hover key" do
      # styleq behavior: ":hover_backgroundColor" and "backgroundColor" are independent
      button = [
        {"background-color", "btn-bg"},
        {"background-color:::hover", "btn-hover"}
      ]

      # Override just the :hover - default should remain
      override = [{"background-color:::hover", "override-hover"}]

      result =
        []
        |> chain_merge(button)
        |> chain_merge(override)

      classes = PropertyMerger.to_class_list(result)

      # Default bg should remain (different key)
      assert "btn-bg" in classes
      # Button hover should be replaced by override hover (same key)
      refute "btn-hover" in classes
      assert "override-hover" in classes
    end

    test "simple property overrides conditional default but not hover" do
      # In StyleX: "color" overrides "color" (default), but not ":hover_color"
      button = [
        {"color", "btn-color"},
        {"color:::hover", "btn-hover-color"}
      ]

      # Override with simple color - replaces default, keeps hover
      override = [{"color", "override-color"}]

      result =
        []
        |> chain_merge(button)
        |> chain_merge(override)

      classes = PropertyMerger.to_class_list(result)

      # btn-color replaced by override-color (same key)
      refute "btn-color" in classes
      assert "override-color" in classes
      # hover is independent, still present
      assert "btn-hover-color" in classes
    end

    test "mixed properties - each key is independent" do
      button = [
        {"display", "flex"},
        {"color", "btn-color"},
        {"color:::hover", "btn-hover-color"},
        {"padding", "p-4"}
      ]

      # Override one conditional
      override = [{"color:::hover", "override-hover"}]

      result =
        []
        |> chain_merge(button)
        |> chain_merge(override)

      classes = PropertyMerger.to_class_list(result)

      # All remain except the one overridden key
      assert "flex" in classes
      assert "p-4" in classes
      assert "btn-color" in classes
      refute "btn-hover-color" in classes
      assert "override-hover" in classes
    end

    test "complex nested merge like styleq test" do
      # Based on styleq's "dedupes class names in complex merges" test
      styles_a = [{"backgroundColor", "bg-a"}, {"display", "display-a"}]
      styles_b = [{"cursor", "cursor-b"}]
      styles_c = [{"cursor", "cursor-c"}, {"display", "display-c"}]

      result =
        []
        |> chain_merge(styles_a)
        |> chain_merge(styles_b)
        |> chain_merge(styles_c)

      classes = PropertyMerger.to_class_list(result)

      # backgroundColor from a (only one)
      assert "bg-a" in classes
      # cursor from c (overwrites b)
      refute "cursor-b" in classes
      assert "cursor-c" in classes
      # display from c (overwrites a)
      refute "display-a" in classes
      assert "display-c" in classes
    end
  end

  describe "atom vs string keys" do
    test "handles atom keys" do
      props = [{:color, "x123"}]
      result = PropertyMerger.merge(props, [])

      assert {:color, "x123"} in result
    end

    test "handles string keys" do
      props = [{"color", "x123"}]
      result = PropertyMerger.merge(props, [])

      assert {"color", "x123"} in result
    end

    test "atom and string keys are treated as same key" do
      # Both refer to the same CSS property
      props1 = [{:color, "atom-class"}]
      props2 = [{"color", "string-class"}]

      result =
        []
        |> chain_merge(props1)
        |> chain_merge(props2)

      classes = PropertyMerger.to_class_list(result)

      # Last wins - they should be treated as same key
      assert "string-class" in classes
      # The atom version should be replaced
      assert length(classes) == 1
    end
  end
end
