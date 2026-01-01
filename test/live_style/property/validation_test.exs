defmodule LiveStyle.Property.ValidationTest do
  @moduledoc """
  Tests for CSS property validation.

  Tests the public validation API for checking CSS property names.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Property.Validation

  describe "validate/1" do
    test "returns :ok for known properties" do
      assert Validation.validate("color") == :ok
      assert Validation.validate("background-color") == :ok
      assert Validation.validate("margin") == :ok
    end

    test "returns :ok for custom properties" do
      assert Validation.validate("--my-custom-prop") == :ok
      assert Validation.validate("--theme-color") == :ok
    end

    test "returns {:unknown, suggestions} for unknown properties" do
      assert {:unknown, suggestions} = Validation.validate("colr")
      assert "color" in suggestions
    end

    test "returns {:unknown, []} when no similar properties found" do
      assert {:unknown, []} = Validation.validate("zzzznotaproperty")
    end
  end

  describe "known?/1" do
    test "returns true for known properties" do
      assert Validation.known?("color") == true
      assert Validation.known?("display") == true
    end

    test "returns true for custom properties" do
      assert Validation.known?("--custom") == true
    end

    test "returns false for unknown properties" do
      assert Validation.known?("not-a-property") == false
    end

    test "returns true for vendor-prefixed properties" do
      assert Validation.known?("-webkit-transform") == true
      assert Validation.known?("-moz-appearance") == true
    end
  end

  describe "find_suggestions/1" do
    test "returns similar property names" do
      suggestions = Validation.find_suggestions("colr")
      assert "color" in suggestions
    end

    test "returns multiple suggestions sorted by similarity" do
      suggestions = Validation.find_suggestions("backgrund")
      assert not Enum.empty?(suggestions)
      assert Enum.any?(suggestions, &String.contains?(&1, "background"))
    end

    test "returns at most 3 suggestions" do
      suggestions = Validation.find_suggestions("margin")
      assert length(suggestions) <= 3
    end

    test "returns empty list for completely dissimilar input" do
      suggestions = Validation.find_suggestions("xyznothing")
      assert suggestions == []
    end
  end
end
