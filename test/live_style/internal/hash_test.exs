defmodule LiveStyle.Internal.HashTest do
  @moduledoc """
  Tests for the Hash module internals.

  These tests verify the hashing behavior with the current compile-time config.
  The config values tested are:
  - class_name_prefix: "x" (default)
  - debug_class_names: false (default)
  """
  use LiveStyle.TestCase

  alias LiveStyle.Hash

  describe "class_prefix/0" do
    test "returns the configured prefix" do
      assert Hash.class_prefix() == "x"
    end
  end

  describe "create_hash/1" do
    test "returns consistent hash for same input" do
      hash1 = Hash.create_hash("test-input")
      hash2 = Hash.create_hash("test-input")
      assert hash1 == hash2
    end

    test "returns different hash for different input" do
      hash1 = Hash.create_hash("input-a")
      hash2 = Hash.create_hash("input-b")
      refute hash1 == hash2
    end

    test "returns lowercase base36 string" do
      hash = Hash.create_hash("some-input")
      assert hash =~ ~r/^[a-z0-9]+$/
    end
  end

  describe "class_name/4" do
    test "generates class with prefix" do
      class = Hash.class_name("color", "red", [], [])
      assert String.starts_with?(class, "x")
    end

    test "same property/value produces same class" do
      class1 = Hash.class_name("display", "flex", [], [])
      class2 = Hash.class_name("display", "flex", [], [])
      assert class1 == class2
    end

    test "different values produce different classes" do
      class1 = Hash.class_name("color", "red", [], [])
      class2 = Hash.class_name("color", "blue", [], [])
      refute class1 == class2
    end

    test "pseudos affect the hash" do
      class1 = Hash.class_name("color", "red", [], [])
      class2 = Hash.class_name("color", "red", [":hover"], [])
      refute class1 == class2
    end

    test "at-rules affect the hash" do
      class1 = Hash.class_name("color", "red", [], [])
      class2 = Hash.class_name("color", "red", [], ["@media (min-width: 768px)"])
      refute class1 == class2
    end

    test "pseudos are sorted for consistent hashing" do
      # Different order should produce same hash
      class1 = Hash.class_name("color", "red", [":hover", ":active"], [])
      class2 = Hash.class_name("color", "red", [":active", ":hover"], [])
      assert class1 == class2
    end

    test "at-rules are sorted for consistent hashing" do
      class1 = Hash.class_name("color", "red", [], ["@media a", "@media b"])
      class2 = Hash.class_name("color", "red", [], ["@media b", "@media a"])
      assert class1 == class2
    end

    # With debug_class_names: false (default), class is just prefix + hash
    test "class name format without debug (default)" do
      class = Hash.class_name("background-color", "red", [], [])
      # Should be "x" + hash, not "background-color-x" + hash
      assert class =~ ~r/^x[a-z0-9]+$/
      refute class =~ "background-color"
    end
  end

  describe "atomic_class/5" do
    test "generates class for simple property/value" do
      class = Hash.atomic_class("color", "red", nil, nil, nil)
      assert String.starts_with?(class, "x")
    end

    test "handles pseudo-element" do
      class = Hash.atomic_class("content", "''", "::before", nil, nil)
      assert String.starts_with?(class, "x")
    end

    test "handles selector suffix (pseudo-class)" do
      class = Hash.atomic_class("color", "blue", nil, ":hover", nil)
      assert String.starts_with?(class, "x")
    end

    test "handles at-rule" do
      class = Hash.atomic_class("font-size", "14px", nil, nil, "@media (max-width: 640px)")
      assert String.starts_with?(class, "x")
    end

    test "handles combined pseudo-element and pseudo-class" do
      class = Hash.atomic_class("color", "blue", "::before", ":hover", nil)
      assert String.starts_with?(class, "x")
    end
  end
end
