defmodule LiveStyle.DevTest do
  @moduledoc """
  Tests for LiveStyle.Dev module - development helpers for inspecting styles.
  """
  use LiveStyle.TestCase, async: true

  alias LiveStyle.Dev

  # Test module with various class types
  defmodule TestComponent do
    use LiveStyle

    css_class(:button,
      display: "flex",
      padding: "8px 16px",
      background_color: "blue"
    )

    css_class(:primary,
      background_color: "blue",
      color: "white"
    )

    css_class(:secondary,
      background_color: "gray",
      color: "black"
    )

    css_class(:hover_style,
      color: [
        default: "blue",
        ":hover": "darkblue"
      ]
    )
  end

  defmodule DynamicComponent do
    use LiveStyle

    css_class(:static, display: "block")

    css_class(:dynamic, fn opacity ->
      [opacity: opacity]
    end)
  end

  describe "list/1" do
    test "returns all class names" do
      classes = Dev.list(TestComponent)
      assert :button in classes
      assert :primary in classes
      assert :secondary in classes
      assert :hover_style in classes
    end

    test "returns sorted list" do
      classes = Dev.list(TestComponent)
      assert classes == Enum.sort(classes)
    end
  end

  describe "list/2" do
    test "filters static classes" do
      static = Dev.list(DynamicComponent, :static)
      assert :static in static
      refute :dynamic in static
    end

    test "filters dynamic classes" do
      dynamic = Dev.list(DynamicComponent, :dynamic)
      assert :dynamic in dynamic
      refute :static in dynamic
    end

    test "returns all with :all filter" do
      all = Dev.list(DynamicComponent, :all)
      assert :static in all
      assert :dynamic in all
    end
  end

  describe "class_info/2" do
    test "returns class details" do
      info = Dev.class_info(TestComponent, :button)

      assert info.name == :button
      assert is_binary(info.class)
      assert is_binary(info.css)
      assert info.dynamic? == false
      assert is_map(info.properties)
    end

    test "properties contain expected values" do
      info = Dev.class_info(TestComponent, :button)

      assert Map.has_key?(info.properties, "display")
      assert info.properties["display"].value == "flex"
      assert is_binary(info.properties["display"].class)
    end

    test "returns error for unknown class" do
      assert {:error, :not_found} = Dev.class_info(TestComponent, :nonexistent)
    end
  end

  describe "diff/2" do
    test "shows merged class string" do
      diff = Dev.diff(TestComponent, [:button, :primary])

      assert is_binary(diff.merged_class)
      assert diff.refs == [:button, :primary]
    end

    test "tracks property sources" do
      diff = Dev.diff(TestComponent, [:button, :primary])

      # button defines display and padding
      assert diff.properties["display"].from == :button
      assert diff.properties["padding"].from == :button

      # primary overrides background-color and adds color
      assert diff.properties["background-color"].from == :primary
      assert diff.properties["color"].from == :primary
    end

    test "later refs override earlier ones" do
      # button has background-color: blue, primary also has background-color: blue
      # but primary should be marked as the source since it comes later
      diff = Dev.diff(TestComponent, [:button, :primary])

      assert diff.properties["background-color"].from == :primary
    end
  end

  describe "css/2" do
    test "returns CSS for single class" do
      css = Dev.css(TestComponent, :button)

      assert is_binary(css)
      assert css =~ "display:flex"
      assert css =~ "padding:8px 16px"
      assert css =~ "background-color:blue"
    end

    test "returns CSS for multiple classes" do
      css = Dev.css(TestComponent, [:button, :primary])

      assert is_binary(css)
      assert css =~ "display:flex"
      assert css =~ "color:white"
    end

    test "returns empty string for unknown class" do
      css = Dev.css(TestComponent, :nonexistent)
      assert css == ""
    end
  end

  describe "pp/2" do
    test "prints class info to console" do
      # Capture IO output
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dev.pp(TestComponent, :button)
        end)

      assert output =~ ":button"
      assert output =~ "display"
      assert output =~ "flex"
    end

    test "returns :ok" do
      result =
        ExUnit.CaptureIO.capture_io(fn ->
          assert Dev.pp(TestComponent, :button) == :ok
        end)

      assert result =~ ":button"
    end
  end

  describe "pp_list/1" do
    test "prints all classes in module" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dev.pp_list(TestComponent)
        end)

      assert output =~ "TestComponent"
      assert output =~ ":button"
      assert output =~ ":primary"
      assert output =~ ":secondary"
    end

    test "returns :ok" do
      result =
        ExUnit.CaptureIO.capture_io(fn ->
          assert Dev.pp_list(TestComponent) == :ok
        end)

      assert result =~ "TestComponent"
    end
  end

  describe "error handling" do
    test "raises for non-LiveStyle module" do
      assert_raise ArgumentError, ~r/is not a LiveStyle module/, fn ->
        Dev.list(Enum)
      end
    end

    test "raises for non-existent module" do
      assert_raise ArgumentError, ~r/is not a LiveStyle module/, fn ->
        Dev.list(NonExistentModule)
      end
    end
  end
end
