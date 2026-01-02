defmodule LiveStyle.DevTest do
  @moduledoc """
  Tests for the LiveStyle.Dev module.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Dev

  defmodule TestStyles do
    use LiveStyle

    class(:button,
      display: "flex",
      padding: "8px 16px"
    )

    class(:primary,
      background_color: "blue",
      color: "white"
    )

    class(:hover_effect,
      color: [
        default: "blue",
        ":hover": "darkblue"
      ]
    )

    class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)
  end

  describe "list/1" do
    test "returns all class names in a module" do
      classes = Dev.list(TestStyles)

      assert is_list(classes)
      assert :button in classes
      assert :primary in classes
      assert :hover_effect in classes
      assert :dynamic_opacity in classes
    end

    test "raises for non-LiveStyle module" do
      assert_raise ArgumentError, ~r/not a LiveStyle module/, fn ->
        Dev.list(Enum)
      end
    end

    test "raises for non-existent module" do
      assert_raise ArgumentError, ~r/not loaded/, fn ->
        Dev.list(NonExistentModule)
      end
    end
  end

  describe "show/2" do
    test "returns :ok for static class" do
      assert :ok = Dev.show(TestStyles, :button)
    end

    test "returns :ok for class with conditionals" do
      assert :ok = Dev.show(TestStyles, :hover_effect)
    end

    test "returns :ok for dynamic class" do
      assert :ok = Dev.show(TestStyles, :dynamic_opacity)
    end

    test "returns :ok for non-existent class" do
      # Should not raise, just show empty
      assert :ok = Dev.show(TestStyles, :nonexistent)
    end
  end

  describe "diff/2" do
    test "returns :ok for multiple classes" do
      assert :ok = Dev.diff(TestStyles, [:button, :primary])
    end

    test "returns :ok for single class list" do
      assert :ok = Dev.diff(TestStyles, [:button])
    end

    test "returns :ok for empty list" do
      assert :ok = Dev.diff(TestStyles, [])
    end
  end

  describe "css/2" do
    test "returns CSS string for static class" do
      css = Dev.css(TestStyles, [:button])

      assert is_binary(css)
      assert css =~ "display:flex"
      assert css =~ "padding:8px 16px"
    end

    test "returns CSS string for multiple classes" do
      css = Dev.css(TestStyles, [:button, :primary])

      assert is_binary(css)
      assert css =~ "display:flex"
      assert css =~ "background-color:blue"
    end

    test "returns CSS for class with conditionals" do
      css = Dev.css(TestStyles, [:hover_effect])

      assert is_binary(css)
      assert css =~ "color:blue"
      assert css =~ ":hover"
      assert css =~ "color:darkblue"
    end

    test "returns empty string for non-existent class" do
      css = Dev.css(TestStyles, [:nonexistent])
      assert css == ""
    end

    test "returns empty string for empty list" do
      css = Dev.css(TestStyles, [])
      assert css == ""
    end
  end

  describe "pp/2" do
    test "is an alias for show/2" do
      # Both should return :ok and not raise
      assert :ok = Dev.pp(TestStyles, :button)
      assert :ok = Dev.show(TestStyles, :button)
    end
  end
end
