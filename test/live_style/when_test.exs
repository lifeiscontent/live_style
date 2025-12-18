defmodule LiveStyle.WhenTest do
  @moduledoc """
  Tests for LiveStyle.When contextual selectors.

  These tests verify that LiveStyle's When module functions match StyleX's when API:
  - when.ancestor() -> When.ancestor()
  - when.descendant() -> When.descendant()
  - when.siblingBefore() -> When.sibling_before()
  - when.siblingAfter() -> When.sibling_after()
  - when.anySibling() -> When.any_sibling()
  - defaultMarker() -> Marker.default()

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-when-test.js
  """
  use LiveStyle.TestCase, async: true

  alias LiveStyle.Marker
  alias LiveStyle.When

  # ===========================================================================
  # Test Modules - Integration with css_rule
  # ===========================================================================

  defmodule WhenAncestorExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:card,
      background_color: %{
        :default => "blue",
        When.ancestor(":hover") => "red"
      }
    )
  end

  defmodule WhenSiblingBeforeExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:label,
      color: %{
        :default => "black",
        When.sibling_before(":focus") => "blue"
      }
    )
  end

  defmodule WhenSiblingAfterExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:hint,
      visibility: %{
        :default => "hidden",
        When.sibling_after(":focus") => "visible"
      }
    )
  end

  defmodule WhenAnySiblingExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:tab,
      opacity: %{
        :default => "1",
        When.any_sibling(":hover") => "0.7"
      }
    )
  end

  defmodule WhenDescendantExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:container,
      border_color: %{
        :default => "gray",
        When.descendant(":focus") => "blue"
      }
    )
  end

  defmodule WhenWithCustomMarkerExample do
    use LiveStyle
    alias LiveStyle.When

    @card_marker Marker.define(:card)

    css_rule(:child,
      transform: %{
        :default => "translateX(0)",
        When.ancestor(":hover", @card_marker) => "translateX(10px)"
      }
    )
  end

  defmodule WhenMultipleConditionsExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:item,
      background_color: %{
        :default => "white",
        When.ancestor(":hover") => "lightblue",
        When.sibling_before(":focus") => "lightgreen",
        ":hover" => "gray"
      }
    )
  end

  defmodule WhenWithMediaQueryExample do
    use LiveStyle
    alias LiveStyle.When

    css_rule(:responsive_card,
      background_color: %{
        :default => "blue",
        When.ancestor(":hover") => "red",
        "@media (min-width: 768px)" => %{
          :default => "green",
          When.ancestor(":hover") => "yellow"
        }
      }
    )
  end

  # ===========================================================================
  # ancestor/1 and ancestor/2 tests
  # ===========================================================================

  describe "ancestor/1" do
    test "generates correct selector for :hover" do
      # StyleX generates: :where(.x-default-marker:hover *)
      selector = When.ancestor(":hover")
      assert selector == ":where(.x-default-marker:hover *)"
    end

    test "generates correct selector for :focus" do
      selector = When.ancestor(":focus")
      assert selector == ":where(.x-default-marker:focus *)"
    end

    test "generates correct selector for :active" do
      selector = When.ancestor(":active")
      assert selector == ":where(.x-default-marker:active *)"
    end

    test "generates correct selector for :focus-visible" do
      selector = When.ancestor(":focus-visible")
      assert selector == ":where(.x-default-marker:focus-visible *)"
    end

    test "generates correct selector for :focus-within" do
      selector = When.ancestor(":focus-within")
      assert selector == ":where(.x-default-marker:focus-within *)"
    end
  end

  describe "ancestor/2 with custom marker" do
    test "uses custom marker class" do
      marker = Marker.define(:card)
      selector = When.ancestor(":hover", marker)
      assert selector == ":where(.#{marker}:hover *)"
    end

    test "supports different markers for different contexts" do
      row_marker = Marker.define(:row)
      card_marker = Marker.define(:card)

      row_selector = When.ancestor(":hover", row_marker)
      card_selector = When.ancestor(":hover", card_marker)

      assert row_selector != card_selector
      assert row_selector == ":where(.#{row_marker}:hover *)"
      assert card_selector == ":where(.#{card_marker}:hover *)"
    end
  end

  # ===========================================================================
  # descendant/1 and descendant/2 tests
  # ===========================================================================

  describe "descendant/1" do
    test "generates correct selector for :focus" do
      # StyleX generates: :where(:has(.x-default-marker:focus))
      selector = When.descendant(":focus")
      assert selector == ":where(:has(.x-default-marker:focus))"
    end

    test "generates correct selector for :hover" do
      selector = When.descendant(":hover")
      assert selector == ":where(:has(.x-default-marker:hover))"
    end

    test "generates correct selector for :checked" do
      selector = When.descendant(":checked")
      assert selector == ":where(:has(.x-default-marker:checked))"
    end
  end

  describe "descendant/2 with custom marker" do
    test "uses custom marker class" do
      marker = Marker.define(:input)
      selector = When.descendant(":focus", marker)
      assert selector == ":where(:has(.#{marker}:focus))"
    end
  end

  # ===========================================================================
  # sibling_before/1 and sibling_before/2 tests
  # ===========================================================================

  describe "sibling_before/1" do
    test "generates correct selector for :focus" do
      # StyleX generates: :where(.x-default-marker:focus ~ *)
      selector = When.sibling_before(":focus")
      assert selector == ":where(.x-default-marker:focus ~ *)"
    end

    test "generates correct selector for :hover" do
      selector = When.sibling_before(":hover")
      assert selector == ":where(.x-default-marker:hover ~ *)"
    end

    test "generates correct selector for :checked" do
      selector = When.sibling_before(":checked")
      assert selector == ":where(.x-default-marker:checked ~ *)"
    end
  end

  describe "sibling_before/2 with custom marker" do
    test "uses custom marker class" do
      marker = Marker.define(:checkbox)
      selector = When.sibling_before(":checked", marker)
      assert selector == ":where(.#{marker}:checked ~ *)"
    end
  end

  # ===========================================================================
  # sibling_after/1 and sibling_after/2 tests
  # ===========================================================================

  describe "sibling_after/1" do
    test "generates correct selector for :focus" do
      # StyleX generates: :where(:has(~ .x-default-marker:focus))
      selector = When.sibling_after(":focus")
      assert selector == ":where(:has(~ .x-default-marker:focus))"
    end

    test "generates correct selector for :hover" do
      selector = When.sibling_after(":hover")
      assert selector == ":where(:has(~ .x-default-marker:hover))"
    end
  end

  describe "sibling_after/2 with custom marker" do
    test "uses custom marker class" do
      marker = Marker.define(:label)
      selector = When.sibling_after(":focus", marker)
      assert selector == ":where(:has(~ .#{marker}:focus))"
    end
  end

  # ===========================================================================
  # any_sibling/1 and any_sibling/2 tests
  # ===========================================================================

  describe "any_sibling/1" do
    test "generates correct selector for :hover" do
      # StyleX generates: :where(.x-default-marker:hover ~ *, :has(~ .x-default-marker:hover))
      selector = When.any_sibling(":hover")
      assert selector == ":where(.x-default-marker:hover ~ *, :has(~ .x-default-marker:hover))"
    end

    test "generates correct selector for :active" do
      # From StyleX test: :where(.x-default-marker:active ~ *, :has(~ .x-default-marker:active))
      selector = When.any_sibling(":active")
      assert selector == ":where(.x-default-marker:active ~ *, :has(~ .x-default-marker:active))"
    end

    test "generates correct selector for :focus" do
      selector = When.any_sibling(":focus")
      assert selector == ":where(.x-default-marker:focus ~ *, :has(~ .x-default-marker:focus))"
    end
  end

  describe "any_sibling/2 with custom marker" do
    test "uses custom marker class" do
      marker = Marker.define(:tab)
      selector = When.any_sibling(":hover", marker)
      assert selector == ":where(.#{marker}:hover ~ *, :has(~ .#{marker}:hover))"
    end
  end

  # ===========================================================================
  # marker/0 and marker/1 tests
  # ===========================================================================

  describe "marker/0" do
    test "returns default marker class name" do
      # StyleX uses: x-default-marker
      marker = Marker.default()
      assert marker == "x-default-marker"
    end
  end

  describe "marker/1" do
    test "creates unique marker class name" do
      marker = Marker.define(:custom)
      assert is_binary(marker)
      assert marker != ""
    end

    test "different names produce different markers" do
      marker1 = Marker.define(:card)
      marker2 = Marker.define(:row)
      assert marker1 != marker2
    end

    test "same name produces consistent marker" do
      marker1 = Marker.define(:test)
      marker2 = Marker.define(:test)
      assert marker1 == marker2
    end
  end

  # ===========================================================================
  # Validation tests
  # ===========================================================================

  describe "validation" do
    test "ancestor rejects pseudo-elements" do
      # StyleX throws: "Pseudo selector cannot start with '::'
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/i, fn ->
        When.ancestor("::before")
      end
    end

    test "ancestor requires colon prefix" do
      # StyleX throws: "Pseudo selector must start with ':'"
      assert_raise ArgumentError, ~r/must start with/i, fn ->
        When.ancestor("hover")
      end
    end

    test "descendant rejects pseudo-elements" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/i, fn ->
        When.descendant("::after")
      end
    end

    test "descendant requires colon prefix" do
      assert_raise ArgumentError, ~r/must start with/i, fn ->
        When.descendant("focus")
      end
    end

    test "sibling_before rejects pseudo-elements" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/i, fn ->
        When.sibling_before("::placeholder")
      end
    end

    test "sibling_before requires colon prefix" do
      assert_raise ArgumentError, ~r/must start with/i, fn ->
        When.sibling_before("checked")
      end
    end

    test "sibling_after rejects pseudo-elements" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/i, fn ->
        When.sibling_after("::selection")
      end
    end

    test "sibling_after requires colon prefix" do
      assert_raise ArgumentError, ~r/must start with/i, fn ->
        When.sibling_after("active")
      end
    end

    test "any_sibling rejects pseudo-elements" do
      assert_raise ArgumentError, ~r/Pseudo-elements.*not supported/i, fn ->
        When.any_sibling("::marker")
      end
    end

    test "any_sibling requires colon prefix" do
      assert_raise ArgumentError, ~r/must start with/i, fn ->
        When.any_sibling("hover")
      end
    end
  end

  # ===========================================================================
  # Integration tests with css_rule
  # ===========================================================================

  describe "integration with css_rule" do
    test "ancestor generates correct CSS in rules" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenAncestorExample, :card)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""

      # Check that we have both a default and conditional class
      assert map_size(rule.atomic_classes) > 0
    end

    test "sibling_before generates correct CSS in rules" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenSiblingBeforeExample, :label)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end

    test "sibling_after generates correct CSS in rules" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenSiblingAfterExample, :hint)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end

    test "any_sibling generates correct CSS in rules" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenAnySiblingExample, :tab)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end

    test "descendant generates correct CSS in rules" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenDescendantExample, :container)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end

    test "ancestor with custom marker generates correct CSS" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenWithCustomMarkerExample, :child)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end

    test "multiple when conditions work together" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenMultipleConditionsExample, :item)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""

      # Should have multiple classes for the different conditions
      classes = String.split(rule.class_string, " ")
      assert length(classes) >= 3
    end

    test "when selectors work with media queries" do
      manifest = get_manifest()
      key = LiveStyle.Manifest.simple_key(WhenWithMediaQueryExample, :responsive_card)
      rule = LiveStyle.Manifest.get_rule(manifest, key)

      assert rule != nil
      assert rule.class_string != ""
    end
  end

  # ===========================================================================
  # Marker module tests
  # ===========================================================================

  describe "LiveStyle.Marker" do
    test "default/0 returns expected format" do
      marker = Marker.default()
      assert marker == "x-default-marker"
    end

    test "define/1 creates hashed marker names" do
      marker = Marker.define(:custom_marker)
      assert is_binary(marker)
      # Should be a hashed value, not the raw name
      refute marker == "custom_marker"
    end

    test "define/1 is deterministic" do
      marker1 = Marker.define(:test_marker)
      marker2 = Marker.define(:test_marker)
      assert marker1 == marker2
    end
  end
end
