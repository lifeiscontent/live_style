defmodule LiveStyle.AttrsTest do
  @moduledoc """
  Tests for LiveStyle.Attrs struct and cross-component property merging.

  These tests verify that when spreading css() onto a component, the property
  classes are properly passed and merged with the component's own styles.
  This matches StyleX's behavior where later styles override earlier ones.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Attrs
  alias LiveStyle.Runtime.PropertyMerger
  alias Phoenix.HTML.Safe

  # Simulates a parent component that passes styles
  defmodule ParentStyles do
    use LiveStyle

    class(:override_color,
      color: [
        default: "red",
        ":hover": "darkred"
      ]
    )

    class(:override_bg,
      background_color: "blue"
    )

    class(:full_override,
      color: [
        default: "green",
        ":hover": "darkgreen"
      ],
      background_color: [
        default: "yellow",
        ":hover": "gold"
      ],
      border_color: "transparent"
    )
  end

  # Simulates a button component with its own styles
  defmodule ButtonStyles do
    use LiveStyle

    class(:btn_base,
      display: "inline-flex",
      padding: "8px 16px",
      border_radius: "4px"
    )

    class(:btn_primary,
      color: "white",
      background_color: [
        default: "purple",
        ":hover": "darkpurple"
      ]
    )
  end

  describe "Attrs struct" do
    test "stores prop_classes alongside class string" do
      attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [:override_color], nil)

      assert is_binary(attrs.class)
      assert attrs.class != ""
      assert is_list(attrs.prop_classes)
      refute Enum.empty?(attrs.prop_classes)
    end

    test "to_list passes Attrs struct as class value" do
      attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [:override_color], nil)
      list = Attrs.to_list(attrs)

      class_value = Keyword.get(list, :class)
      assert %Attrs{} = class_value
      assert class_value.prop_classes == attrs.prop_classes
    end

    test "Phoenix.HTML.Safe converts to class string" do
      attrs = %Attrs{class: "foo bar", style: nil, prop_classes: [{"color", "foo"}]}

      # Safe.to_iodata should return just the class string
      iodata = Safe.to_iodata(attrs)
      assert IO.iodata_to_binary(iodata) == "foo bar"
    end

    test "empty Attrs produces empty list" do
      attrs = %Attrs{class: "", style: nil, prop_classes: []}
      list = Attrs.to_list(attrs)

      assert list == []
    end
  end

  describe "cross-component property merging" do
    test "Attrs struct in refs is recognized and merged" do
      # Parent creates Attrs with prop_classes
      parent_attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [:override_color], nil)

      # Button receives Attrs and merges
      button_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, :btn_primary, parent_attrs],
          nil
        )

      # Should have classes from all three sources
      assert is_binary(button_attrs.class)
      assert button_attrs.class != ""

      # The merged prop_classes should include properties from parent override
      prop_names = Enum.map(button_attrs.prop_classes, fn {prop, _class} -> prop end)
      assert "color::default" in prop_names or "color" in prop_names
    end

    test "conditional default conflicts with simple props (StyleX behavior)" do
      # btn_primary has simple color: "white"
      # override_color has color: [default: "red", ":hover": "darkred"]
      # In StyleX, "default" produces "color" key, so it conflicts with simple "color"

      btn_primary_props =
        ButtonStyles.__live_style__(:property_classes)
        |> Keyword.get(:btn_primary, [])

      override_props =
        ParentStyles.__live_style__(:property_classes)
        |> Keyword.get(:override_color, [])

      # Verify btn_primary has simple color
      assert Enum.any?(btn_primary_props, fn {prop, _} -> prop == "color" end)

      # Verify override has color (from default) and color:::hover
      assert Enum.any?(override_props, fn {prop, _} -> prop == "color" end)
      assert Enum.any?(override_props, fn {prop, _} -> prop == "color:::hover" end)

      # Merge: btn_primary first, then override
      merged = PropertyMerger.merge(btn_primary_props, [])
      merged = PropertyMerger.merge(override_props, merged)

      # StyleX behavior: "color" key is overridden (last wins), hover is independent
      prop_names = Enum.map(merged, fn {prop, _} -> to_string(prop) end)
      assert "color" in prop_names
      assert "color:::hover" in prop_names
      # There should be exactly one "color" entry
      assert Enum.count(prop_names, &(&1 == "color")) == 1
    end

    test "simple props override conditional default (StyleX behavior)" do
      # override_color has color: [default: "red", ":hover": "darkred"]
      # Then apply a simple color override
      # In StyleX, simple "color" overrides the "color" from default, hover is independent

      override_props =
        ParentStyles.__live_style__(:property_classes)
        |> Keyword.get(:override_color, [])

      simple_override = [{"color", "simple-class"}]

      # Merge: conditional first, then simple
      merged = PropertyMerger.merge(override_props, [])
      merged = PropertyMerger.merge(simple_override, merged)

      # StyleX behavior: last "color" wins, hover is independent
      prop_names = Enum.map(merged, fn {prop, _} -> to_string(prop) end)
      assert "color" in prop_names
      assert "color:::hover" in prop_names
      # Verify the value is from simple_override
      assert {"color", "simple-class"} in merged
    end

    test "false condition produces empty Attrs" do
      attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [false && :override_color], nil)

      assert attrs.class == ""
      assert attrs.prop_classes == []
    end

    test "nil in refs is ignored" do
      attrs =
        LiveStyle.Runtime.resolve_attrs(ParentStyles, [:override_color, nil, :override_bg], nil)

      assert is_binary(attrs.class)
      assert attrs.class != ""
    end

    test "Attrs with empty prop_classes falls back to class string" do
      # Create an Attrs with no prop_classes (like from external CSS)
      external_attrs = %Attrs{class: "external-class", style: nil, prop_classes: nil}

      # Merge with button styles
      button_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, external_attrs],
          nil
        )

      # The external class should be appended
      assert String.contains?(button_attrs.class, "external-class")
    end

    test "full component simulation - active button (StyleX behavior)" do
      # Simulate: <.button {css([:full_override])}>
      parent_attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [:full_override], nil)

      # Button spreads this, receiving @class as Attrs
      spread_list = Attrs.to_list(parent_attrs)
      class_value = Keyword.get(spread_list, :class)

      # Button merges: {css([:btn_base, :btn_primary, @class])}
      button_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, :btn_primary, class_value],
          nil
        )

      # Get the property class mappings
      btn_primary_props =
        ButtonStyles.__live_style__(:property_classes)
        |> Keyword.get(:btn_primary, [])

      full_override_props =
        ParentStyles.__live_style__(:property_classes)
        |> Keyword.get(:full_override, [])

      # Extract class names for comparison
      btn_color_class =
        Enum.find_value(btn_primary_props, fn
          {"color", class} -> class
          _ -> nil
        end)

      # full_override has color: [default: ...] which produces "color" key (not "color::default")
      override_color_class =
        Enum.find_value(full_override_props, fn
          {"color", class} -> class
          _ -> nil
        end)

      # StyleX behavior: override's "color" replaces button's "color" (same key, last wins)
      # Button's simple color should NOT be in final output
      refute btn_color_class && String.contains?(button_attrs.class, btn_color_class)

      # Override's color SHOULD be in final output (it comes last)
      assert override_color_class && String.contains?(button_attrs.class, override_color_class)
    end

    test "full component simulation - inactive button" do
      # Simulate: <.button {css([false && :full_override])}>
      parent_attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, [false && :full_override], nil)

      # Button spreads this, receiving @class as nil (empty spread)
      spread_list = Attrs.to_list(parent_attrs)
      class_value = Keyword.get(spread_list, :class)

      # Button merges: {css([:btn_base, :btn_primary, @class])}
      button_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, :btn_primary, class_value],
          nil
        )

      # Get btn_primary's color class
      btn_primary_props =
        ButtonStyles.__live_style__(:property_classes)
        |> Keyword.get(:btn_primary, [])

      btn_color_class =
        Enum.find_value(btn_primary_props, fn
          {"color", class} -> class
          _ -> nil
        end)

      # Button's simple color SHOULD be in final output (no override)
      assert btn_color_class && String.contains?(button_attrs.class, btn_color_class)
    end
  end

  describe "StyleX parity" do
    test "hover props override default props independently" do
      # StyleX test case: first has bg + :hover_bg, third overrides :hover_bg only
      # "default" condition produces just the property name
      style1 = [{"background-color", "bg1"}]

      style2 = [
        {"background-color", "bg2"},
        {"background-color:::hover", "hover1"}
      ]

      style3 = [
        {"color", "color1"},
        {"background-color:::hover", "hover2"}
      ]

      merged = PropertyMerger.merge(style1, [])
      merged = PropertyMerger.merge(style2, merged)
      merged = PropertyMerger.merge(style3, merged)

      classes = PropertyMerger.to_class_list(merged)

      # bg2 should be present (from style2, overriding style1)
      assert "bg2" in classes
      # color1 should be present (from style3)
      assert "color1" in classes
      # hover2 should be present (from style3, overriding style2's hover1)
      assert "hover2" in classes
      # hover1 should NOT be present (overridden by hover2)
      refute "hover1" in classes
    end

    test "nested arrays are flattened" do
      # StyleX flattens nested arrays in props()
      nested_refs = [
        :override_color,
        [:override_bg]
      ]

      attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, nested_refs, nil)

      # Should contain classes from both
      assert is_binary(attrs.class)
      assert attrs.class != ""

      # Prop classes should include both color and background-color
      prop_names = Enum.map(attrs.prop_classes, fn {prop, _} -> to_string(prop) end)
      color_props = Enum.filter(prop_names, &String.starts_with?(&1, "color"))
      bg_props = Enum.filter(prop_names, &String.starts_with?(&1, "background-color"))

      refute Enum.empty?(color_props)
      refute Enum.empty?(bg_props)
    end

    test "falsy values are filtered" do
      # StyleX filters nil, false, ""
      refs = [
        :override_color,
        nil,
        false,
        "",
        :override_bg
      ]

      attrs = LiveStyle.Runtime.resolve_attrs(ParentStyles, refs, nil)

      # Should work without error and include both valid refs
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  describe "marker class preservation" do
    test "marker classes survive cross-component merging" do
      # This tests the anchor positioning tooltip issue where
      # Marker.default() was being lost when spreading onto components

      # Parent creates Attrs with property classes AND a marker
      parent_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ParentStyles,
          [:override_color, LiveStyle.Marker.default()],
          nil
        )

      # Parent should have both prop classes and marker
      assert String.contains?(parent_attrs.class, "x-default-marker")

      # Spread onto component
      spread_list = Attrs.to_list(parent_attrs)
      class_value = Keyword.get(spread_list, :class)

      # Component merges with its own styles
      merged_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, class_value],
          nil
        )

      # Marker should survive the merge
      assert String.contains?(merged_attrs.class, "x-default-marker")
    end

    test "multiple extra classes survive merging" do
      # Create Attrs with prop_classes and multiple extra classes
      attrs_with_extras = %Attrs{
        class: "prop-class extra1 extra2 extra3",
        style: nil,
        prop_classes: [{"some-prop", "prop-class"}]
      }

      # Merge into button
      merged_attrs =
        LiveStyle.Runtime.resolve_attrs(
          ButtonStyles,
          [:btn_base, attrs_with_extras],
          nil
        )

      # All extra classes should be present
      assert String.contains?(merged_attrs.class, "extra1")
      assert String.contains?(merged_attrs.class, "extra2")
      assert String.contains?(merged_attrs.class, "extra3")

      # Prop class should also be present (merged)
      assert String.contains?(merged_attrs.class, "prop-class")
    end
  end

  describe "css_class/1" do
    defmodule CssClassTestModule do
      use LiveStyle

      class(:toast_hiding,
        opacity: "0",
        transform: "translateY(0.5rem)"
      )

      class(:highlight, background_color: "yellow")

      # Test using css_class in a function (typical JS usage)
      def get_hiding_class, do: css_class(:toast_hiding)
      def get_highlight_class, do: css_class(:highlight)
    end

    test "returns class string for local ref" do
      class = CssClassTestModule.get_hiding_class()
      assert is_binary(class)
      assert class != ""
    end

    test "returns different class for different styles" do
      hiding = CssClassTestModule.get_hiding_class()
      highlight = CssClassTestModule.get_highlight_class()

      assert hiding != highlight
    end

    test "returns same class as css/1" do
      # Get class via the Compiler helper
      attrs = LiveStyle.Compiler.get_css(CssClassTestModule, [:toast_hiding])
      direct_class = CssClassTestModule.get_hiding_class()

      # Compare as sets since order may differ
      css_classes = String.split(attrs.class) |> MapSet.new()
      direct_classes = String.split(direct_class) |> MapSet.new()

      assert css_classes == direct_classes
    end
  end
end
