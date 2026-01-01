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
  use LiveStyle.TestCase

  alias LiveStyle.Compiler.Class
  alias LiveStyle.Marker
  alias LiveStyle.When

  # ===========================================================================
  # Test Modules - Integration with class
  # ===========================================================================

  defmodule WhenAncestorExample do
    use LiveStyle
    alias LiveStyle.When

    class(:card,
      background_color: [
        {:default, "blue"},
        {When.ancestor(":hover"), "red"}
      ]
    )
  end

  defmodule WhenSiblingBeforeExample do
    use LiveStyle
    alias LiveStyle.When

    class(:label,
      color: [
        {:default, "black"},
        {When.sibling_before(":focus"), "blue"}
      ]
    )
  end

  defmodule WhenSiblingAfterExample do
    use LiveStyle
    alias LiveStyle.When

    class(:hint,
      visibility: [
        {:default, "hidden"},
        {When.sibling_after(":focus"), "visible"}
      ]
    )
  end

  defmodule WhenAnySiblingExample do
    use LiveStyle
    alias LiveStyle.When

    class(:tab,
      opacity: [
        {:default, "1"},
        {When.any_sibling(":hover"), "0.7"}
      ]
    )
  end

  defmodule WhenDescendantExample do
    use LiveStyle
    alias LiveStyle.When

    class(:container,
      border_color: [
        {:default, "gray"},
        {When.descendant(":focus"), "blue"}
      ]
    )
  end

  defmodule WhenWithCustomMarkerExample do
    use LiveStyle
    alias LiveStyle.When

    @card_marker Marker.ref(:card)

    class(:child,
      transform: [
        {:default, "translateX(0)"},
        {When.ancestor(":hover", @card_marker), "translateX(10px)"}
      ]
    )
  end

  defmodule WhenMultipleConditionsExample do
    use LiveStyle
    alias LiveStyle.When

    class(:item,
      background_color: [
        {:default, "white"},
        {When.ancestor(":hover"), "lightblue"},
        {When.sibling_before(":focus"), "lightgreen"},
        {":hover", "gray"}
      ]
    )
  end

  defmodule WhenWithMediaQueryExample do
    use LiveStyle
    alias LiveStyle.When

    class(:responsive_card,
      background_color: [
        {:default, "blue"},
        {When.ancestor(":hover"), "red"},
        {"@media (min-width: 768px)",
         [
           {:default, "green"},
           {When.ancestor(":hover"), "yellow"}
         ]}
      ]
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
      marker = Marker.ref(:card)
      selector = When.ancestor(":hover", marker)
      assert selector == ":where(.#{Marker.to_class(marker)}:hover *)"
    end

    test "supports different markers for different contexts" do
      row_marker = Marker.ref(:row)
      card_marker = Marker.ref(:card)

      row_selector = When.ancestor(":hover", row_marker)
      card_selector = When.ancestor(":hover", card_marker)

      assert row_selector != card_selector
      assert row_selector == ":where(.#{Marker.to_class(row_marker)}:hover *)"
      assert card_selector == ":where(.#{Marker.to_class(card_marker)}:hover *)"
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
      marker = Marker.ref(:input)
      selector = When.descendant(":focus", marker)
      assert selector == ":where(:has(.#{Marker.to_class(marker)}:focus))"
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
      marker = Marker.ref(:checkbox)
      selector = When.sibling_before(":checked", marker)
      assert selector == ":where(.#{Marker.to_class(marker)}:checked ~ *)"
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
      marker = Marker.ref(:label)
      selector = When.sibling_after(":focus", marker)
      assert selector == ":where(:has(~ .#{Marker.to_class(marker)}:focus))"
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
      marker = Marker.ref(:tab)
      class = Marker.to_class(marker)
      selector = When.any_sibling(":hover", marker)
      assert selector == ":where(.#{class}:hover ~ *, :has(~ .#{class}:hover))"
    end
  end

  # ===========================================================================
  # marker/0 and marker/1 tests
  # ===========================================================================

  describe "Marker.default/0" do
    test "returns default marker struct" do
      # StyleX uses: x-default-marker
      marker = Marker.default()
      assert %Marker{class: "x-default-marker"} = marker
    end
  end

  describe "Marker.ref/1" do
    test "creates marker struct with unique class" do
      marker = Marker.ref(:custom)
      assert %Marker{class: class} = marker
      assert is_binary(class)
      assert class != ""
    end

    test "different names produce different markers" do
      marker1 = Marker.ref(:card)
      marker2 = Marker.ref(:row)
      assert marker1 != marker2
    end

    test "same name produces consistent marker" do
      marker1 = Marker.ref(:test)
      marker2 = Marker.ref(:test)
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
  # Integration tests with class
  # ===========================================================================

  describe "integration with class" do
    test "ancestor generates correct CSS in rules" do
      rule = Class.lookup!({WhenAncestorExample, :card})

      assert rule != nil
      assert rule.class_string != ""

      # Check that we have both a default and conditional class
      assert rule.atomic_classes != []
    end

    test "sibling_before generates correct CSS in rules" do
      rule = Class.lookup!({WhenSiblingBeforeExample, :label})

      assert rule != nil
      assert rule.class_string != ""
    end

    test "sibling_after generates correct CSS in rules" do
      rule = Class.lookup!({WhenSiblingAfterExample, :hint})

      assert rule != nil
      assert rule.class_string != ""
    end

    test "any_sibling generates correct CSS in rules" do
      rule = Class.lookup!({WhenAnySiblingExample, :tab})

      assert rule != nil
      assert rule.class_string != ""
    end

    test "descendant generates correct CSS in rules" do
      rule = Class.lookup!({WhenDescendantExample, :container})

      assert rule != nil
      assert rule.class_string != ""
    end

    test "ancestor with custom marker generates correct CSS" do
      rule = Class.lookup!({WhenWithCustomMarkerExample, :child})

      assert rule != nil
      assert rule.class_string != ""
    end

    test "multiple when conditions work together" do
      rule = Class.lookup!({WhenMultipleConditionsExample, :item})

      assert rule != nil
      assert rule.class_string != ""

      # Should have multiple classes for the different conditions
      classes = String.split(rule.class_string, " ")
      assert length(classes) >= 3
    end

    test "when selectors work with media queries" do
      rule = Class.lookup!({WhenWithMediaQueryExample, :responsive_card})

      assert rule != nil
      assert rule.class_string != ""
    end
  end

  # ===========================================================================
  # Marker module tests
  # ===========================================================================

  describe "LiveStyle.Marker" do
    test "default/0 returns marker struct" do
      marker = Marker.default()
      assert %Marker{class: "x-default-marker"} = marker
    end

    test "ref/1 creates marker struct with hashed class" do
      marker = Marker.ref(:custom_marker)
      assert %Marker{class: class} = marker
      assert is_binary(class)
      # Should be a hashed value, not the raw name
      refute class == "custom_marker"
    end

    test "ref/1 is deterministic" do
      marker1 = Marker.ref(:test_marker)
      marker2 = Marker.ref(:test_marker)
      assert marker1 == marker2
    end

    test "to_class/1 extracts class from struct" do
      marker = Marker.ref(:test)
      assert Marker.to_class(marker) == marker.class
    end

    test "to_class/1 passes through strings" do
      assert Marker.to_class("my-class") == "my-class"
    end
  end
end
