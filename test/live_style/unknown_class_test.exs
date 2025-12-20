defmodule LiveStyle.UnknownClassTest do
  @moduledoc """
  Tests for class resolution behavior with unknown references.

  Unknown class references gracefully return empty strings (like Phoenix
  assigns that don't exist return nil). No validation or errors are raised.
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Test modules
  # ===========================================================================

  defmodule ValidStyles do
    use LiveStyle

    css_class(:button,
      display: "flex",
      padding: "8px 16px"
    )

    css_class(:primary,
      background_color: "blue"
    )

    css_class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)
  end

  defmodule OtherStyles do
    use LiveStyle

    css_class(:card,
      border: "1px solid gray"
    )
  end

  # ===========================================================================
  # Valid references
  # ===========================================================================

  describe "valid class references" do
    test "single atom ref returns class string" do
      class = LiveStyle.get_css_class(ValidStyles, :button)
      assert is_binary(class)
      assert class != ""
    end

    test "list of refs returns merged class string" do
      class = LiveStyle.get_css_class(ValidStyles, [:button, :primary])
      assert is_binary(class)
      assert class != ""
    end

    test "dynamic refs work" do
      attrs = LiveStyle.get_css(ValidStyles, [{:dynamic_opacity, "0.5"}])
      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
    end

    test "cross-module refs work" do
      class = LiveStyle.get_css_class(ValidStyles, [{OtherStyles, :card}])
      assert is_binary(class)
      assert class != ""
    end
  end

  # ===========================================================================
  # Unknown references (graceful degradation)
  # ===========================================================================

  describe "unknown class references" do
    test "unknown single ref returns empty string" do
      class = LiveStyle.get_css_class(ValidStyles, :nonexistent)
      assert class == ""
    end

    test "unknown ref in list is skipped, valid refs work" do
      class = LiveStyle.get_css_class(ValidStyles, [:button, :nonexistent, :primary])
      assert is_binary(class)
      assert class != ""
    end

    test "css/2 with unknown single ref returns empty class" do
      attrs = LiveStyle.get_css(ValidStyles, :nonexistent)
      assert %LiveStyle.Attrs{} = attrs
      assert attrs.class == ""
    end

    test "css/2 with unknown ref in list returns valid classes only" do
      attrs = LiveStyle.get_css(ValidStyles, [:button, :nonexistent])
      assert %LiveStyle.Attrs{} = attrs
      assert is_binary(attrs.class)
      assert attrs.class != ""
    end
  end

  # ===========================================================================
  # Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "nil and false are filtered from list" do
      class = LiveStyle.get_css_class(ValidStyles, [:button, nil, false, :primary])
      assert is_binary(class)
      assert class != ""
    end

    test "empty list returns empty string" do
      class = LiveStyle.get_css_class(ValidStyles, [])
      assert class == ""
    end

    test "list with only nil and false returns empty string" do
      class = LiveStyle.get_css_class(ValidStyles, [nil, false])
      assert class == ""
    end

    test "nested lists are flattened" do
      class = LiveStyle.get_css_class(ValidStyles, [[:button], [:primary]])
      assert is_binary(class)
      assert class != ""
    end
  end
end
