defmodule LiveStyle.Internal.SelectorTest do
  @moduledoc """
  Tests for the Selector module internals.

  These tests verify selector generation with the current compile-time config.
  The config value tested is:
  - use_css_layers: false (default)

  When use_css_layers is false, specificity is bumped using `:not(#\\#)`.
  When use_css_layers is true, specificity is bumped using `.class.class`.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Selector

  describe "build_atomic_rule_selector/4 with use_css_layers: false (default)" do
    test "simple class without modifiers" do
      selector = Selector.build_atomic_rule_selector("xabc123", nil, nil, nil)
      assert selector == ".xabc123"
    end

    test "class with pseudo-class uses :not(#\\#) bump" do
      selector = Selector.build_atomic_rule_selector("xabc123", ":hover", nil, nil)
      # With use_css_layers: false, uses :not(#\#) for specificity bump
      assert selector =~ ":not(#\\#)"
      assert selector =~ ":hover"
    end

    test "class with at-rule uses :not(#\\#) bump" do
      selector = Selector.build_atomic_rule_selector("xabc123", nil, nil, "@media print")
      assert selector =~ ":not(#\\#)"
    end

    test "class with pseudo-element only (no bump needed)" do
      selector = Selector.build_atomic_rule_selector("xabc123", nil, "::before", nil)
      # Pseudo-elements alone don't need specificity bump
      refute selector =~ ":not(#\\#)"
      assert selector =~ "::before"
    end

    test "combined pseudo-element and pseudo-class" do
      selector = Selector.build_atomic_rule_selector("xabc123", ":hover", "::before", nil)
      # pseudo_element takes precedence in suffix, but pseudo-class triggers bump
      assert selector =~ "::before"
    end
  end

  describe "build_atomic_class_selector/3" do
    test "simple class" do
      selector = Selector.build_atomic_class_selector("xabc123", nil, nil)
      assert selector == ".xabc123"
    end

    test "class with simple pseudo-class (no bump)" do
      # Simple pseudo-classes like :hover do NOT trigger specificity bump
      selector = Selector.build_atomic_class_selector("xabc123", ":hover", nil)
      assert selector == ".xabc123:hover"
    end

    test "class with at-rule (gets bump)" do
      # At-rules DO trigger specificity bump
      selector = Selector.build_atomic_class_selector("xabc123", nil, "@media print")
      assert selector == ".xabc123.xabc123"
    end

    test "class with contextual :where() selector (gets bump)" do
      # Contextual selectors like :where() DO trigger bump
      selector = Selector.build_atomic_class_selector("xabc123", ":where(.parent)", nil)
      assert selector =~ ".xabc123.xabc123"
    end

    test "class with contextual :is() selector (gets bump)" do
      selector = Selector.build_atomic_class_selector("xabc123", ":is(.foo, .bar)", nil)
      assert selector =~ ".xabc123.xabc123"
    end
  end

  describe "contextual_selector?/1" do
    test "nil is not contextual" do
      refute Selector.contextual_selector?(nil)
    end

    test ":hover is not contextual" do
      refute Selector.contextual_selector?(":hover")
    end

    test ":where() is contextual" do
      assert Selector.contextual_selector?(":where(.parent)")
    end

    test ":is() is contextual" do
      assert Selector.contextual_selector?(":is(.foo, .bar)")
    end

    test ":has() is contextual" do
      assert Selector.contextual_selector?(":has(.child)")
    end

    test ":not() with space is contextual" do
      assert Selector.contextual_selector?(":not(.foo) .bar")
    end

    test ":not() without space is not contextual" do
      refute Selector.contextual_selector?(":not(.foo)")
    end
  end

  describe "prefix_rtl/1" do
    test "prefixes single selector" do
      result = Selector.prefix_rtl(".xabc123")
      assert result == "html[dir=\"rtl\"] .xabc123"
    end

    test "prefixes multiple selectors" do
      result = Selector.prefix_rtl(".xa, .xb")
      assert result == "html[dir=\"rtl\"] .xa,html[dir=\"rtl\"] .xb"
    end
  end
end
