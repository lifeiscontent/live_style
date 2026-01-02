defmodule LiveStyle.Internal.PriorityTest do
  @moduledoc """
  Tests for priority calculations matching StyleX behavior.

  StyleX priority system from property-priorities.js:
  - Property priorities (base):
    - shorthandsOfShorthands: 1000
    - shorthandsOfLonghands: 2000
    - longHandLogical: 3000
    - longHandPhysical: 4000

  - At-rule priorities (additive):
    - @supports: 30
    - @media: 200
    - @container: 300

  - Pseudo-class priorities (additive):
    - :hover: 130
    - :focus: 150
    - :active: 170
    - (see full list in PSEUDO_CLASS_PRIORITIES)

  - Pseudo-element priority (additive):
    - :: (any pseudo-element): 5000

  Total priority = property_priority + at_rule_priority + pseudo_priority
  """
  use LiveStyle.TestCase

  alias LiveStyle.Pseudo

  # ==========================================================================
  # Pseudo-Class Priority Constants (from StyleX PSEUDO_CLASS_PRIORITIES)
  # ==========================================================================

  describe "pseudo-class priorities match StyleX PSEUDO_CLASS_PRIORITIES" do
    # Logical pseudo-classes
    test ":is priority" do
      assert Pseudo.priority(":is") == 40
    end

    test ":where priority" do
      assert Pseudo.priority(":where") == 40
    end

    test ":not priority" do
      assert Pseudo.priority(":not") == 40
    end

    test ":has priority" do
      assert Pseudo.priority(":has") == 45
    end

    # Language/direction
    test ":dir priority" do
      assert Pseudo.priority(":dir") == 50
    end

    test ":lang priority" do
      assert Pseudo.priority(":lang") == 51
    end

    # Structural pseudo-classes
    test ":first-child priority" do
      assert Pseudo.priority(":first-child") == 52
    end

    test ":first-of-type priority" do
      assert Pseudo.priority(":first-of-type") == 53
    end

    test ":last-child priority" do
      assert Pseudo.priority(":last-child") == 54
    end

    test ":last-of-type priority" do
      assert Pseudo.priority(":last-of-type") == 55
    end

    test ":only-child priority" do
      assert Pseudo.priority(":only-child") == 56
    end

    test ":only-of-type priority" do
      assert Pseudo.priority(":only-of-type") == 57
    end

    test ":nth-child priority" do
      assert Pseudo.priority(":nth-child") == 60
    end

    test ":nth-last-child priority" do
      assert Pseudo.priority(":nth-last-child") == 61
    end

    test ":nth-of-type priority" do
      assert Pseudo.priority(":nth-of-type") == 62
    end

    test ":nth-last-of-type priority" do
      assert Pseudo.priority(":nth-last-of-type") == 63
    end

    test ":empty priority" do
      assert Pseudo.priority(":empty") == 70
    end

    # Link pseudo-classes
    test ":link priority" do
      assert Pseudo.priority(":link") == 80
    end

    test ":any-link priority" do
      assert Pseudo.priority(":any-link") == 81
    end

    test ":local-link priority" do
      assert Pseudo.priority(":local-link") == 82
    end

    test ":target-within priority" do
      assert Pseudo.priority(":target-within") == 83
    end

    test ":target priority" do
      assert Pseudo.priority(":target") == 84
    end

    test ":visited priority" do
      assert Pseudo.priority(":visited") == 85
    end

    # Form state pseudo-classes
    test ":enabled priority" do
      assert Pseudo.priority(":enabled") == 91
    end

    test ":disabled priority" do
      assert Pseudo.priority(":disabled") == 92
    end

    test ":required priority" do
      assert Pseudo.priority(":required") == 93
    end

    test ":optional priority" do
      assert Pseudo.priority(":optional") == 94
    end

    test ":read-only priority" do
      assert Pseudo.priority(":read-only") == 95
    end

    test ":read-write priority" do
      assert Pseudo.priority(":read-write") == 96
    end

    test ":placeholder-shown priority" do
      assert Pseudo.priority(":placeholder-shown") == 97
    end

    test ":in-range priority" do
      assert Pseudo.priority(":in-range") == 98
    end

    test ":out-of-range priority" do
      assert Pseudo.priority(":out-of-range") == 99
    end

    test ":default priority" do
      assert Pseudo.priority(":default") == 100
    end

    test ":checked priority" do
      assert Pseudo.priority(":checked") == 101
    end

    test ":indeterminate priority" do
      assert Pseudo.priority(":indeterminate") == 101
    end

    test ":blank priority" do
      assert Pseudo.priority(":blank") == 102
    end

    test ":valid priority" do
      assert Pseudo.priority(":valid") == 103
    end

    test ":invalid priority" do
      assert Pseudo.priority(":invalid") == 104
    end

    test ":user-invalid priority" do
      assert Pseudo.priority(":user-invalid") == 105
    end

    test ":autofill priority" do
      assert Pseudo.priority(":autofill") == 110
    end

    # Media/fullscreen pseudo-classes
    test ":picture-in-picture priority" do
      assert Pseudo.priority(":picture-in-picture") == 120
    end

    test ":modal priority" do
      assert Pseudo.priority(":modal") == 121
    end

    test ":fullscreen priority" do
      assert Pseudo.priority(":fullscreen") == 122
    end

    test ":paused priority" do
      assert Pseudo.priority(":paused") == 123
    end

    test ":playing priority" do
      assert Pseudo.priority(":playing") == 124
    end

    test ":current priority" do
      assert Pseudo.priority(":current") == 125
    end

    test ":past priority" do
      assert Pseudo.priority(":past") == 126
    end

    test ":future priority" do
      assert Pseudo.priority(":future") == 127
    end

    # User action pseudo-classes (LVHFA order)
    test ":hover priority" do
      assert Pseudo.priority(":hover") == 130
    end

    test ":focus-within priority" do
      assert Pseudo.priority(":focus-within") == 140
    end

    test ":focus priority" do
      assert Pseudo.priority(":focus") == 150
    end

    test ":focus-visible priority" do
      assert Pseudo.priority(":focus-visible") == 160
    end

    test ":active priority" do
      assert Pseudo.priority(":active") == 170
    end

    # Unknown pseudo-class should return default of 40
    test "unknown pseudo-class returns 40" do
      assert Pseudo.priority(":unknown-pseudo") == 40
    end
  end

  # ==========================================================================
  # Pseudo-Element Priority (StyleX PSEUDO_ELEMENT_PRIORITY = 5000)
  # ==========================================================================

  describe "pseudo-element priority matches StyleX PSEUDO_ELEMENT_PRIORITY" do
    test "element_priority/0 returns 5000" do
      assert Pseudo.element_priority() == 5000
    end
  end

  # ==========================================================================
  # Combined Priority Calculations (matching StyleX test outputs)
  # ==========================================================================

  describe "calculate_priority/1 matches StyleX combined priorities" do
    # Simple pseudo-classes
    test ":hover returns 130" do
      assert Pseudo.calculate_priority(":hover") == 130
    end

    test ":active returns 170" do
      assert Pseudo.calculate_priority(":active") == 170
    end

    test ":focus returns 150" do
      assert Pseudo.calculate_priority(":focus") == 150
    end

    # Combined pseudo-classes (additive)
    test ":hover:active returns 300 (130 + 170)" do
      assert Pseudo.calculate_priority(":hover:active") == 300
    end

    test ":focus:hover returns 280 (150 + 130)" do
      assert Pseudo.calculate_priority(":focus:hover") == 280
    end

    # Pseudo-elements
    test "::before returns 5000" do
      assert Pseudo.calculate_priority("::before") == 5000
    end

    test "::after returns 5000" do
      assert Pseudo.calculate_priority("::after") == 5000
    end

    test "::placeholder returns 5000" do
      assert Pseudo.calculate_priority("::placeholder") == 5000
    end

    # Pseudo-element + pseudo-class combinations
    # StyleX test shows: priority: 8130 for ::before:hover (3000 property + 5000 + 130)
    # But calculate_priority only handles the selector suffix, not property
    test "::before:hover returns 5130 (5000 + 130)" do
      assert Pseudo.calculate_priority("::before:hover") == 5130
    end

    test "::after:active returns 5170 (5000 + 170)" do
      assert Pseudo.calculate_priority("::after:active") == 5170
    end

    test "::before:hover:active returns 5300 (5000 + 130 + 170)" do
      assert Pseudo.calculate_priority("::before:hover:active") == 5300
    end

    # nil returns 0
    test "nil returns 0" do
      assert Pseudo.calculate_priority(nil) == 0
    end

    # Functional pseudo-classes (base priority extracted)
    test ":nth-child(2) returns 60 (same as :nth-child)" do
      assert Pseudo.calculate_priority(":nth-child(2)") == 60
    end

    test ":nth-of-type(odd) returns 62 (same as :nth-of-type)" do
      assert Pseudo.calculate_priority(":nth-of-type(odd)") == 62
    end
  end

  # ==========================================================================
  # StyleX Test Case Verification
  # These priorities match exact outputs from StyleX babel-plugin tests
  # ==========================================================================

  describe "matches StyleX babel-plugin test outputs" do
    # From transform-stylex-create-test.js:
    # .x1gykpug:hover{background-color:red} -> priority: 3130
    # This is 3000 (property) + 130 (:hover)
    # We test just the pseudo part here
    test ":hover pseudo contributes 130 to total priority" do
      # In StyleX: total = 3000 (color property) + 130 (:hover) = 3130
      assert Pseudo.calculate_priority(":hover") == 130
    end

    # .x16oeupf::before{color:red} -> priority: 8000
    # This is 3000 (property) + 5000 (::before)
    test "::before pseudo contributes 5000 to total priority" do
      assert Pseudo.calculate_priority("::before") == 5000
    end

    # .xeb2lg0::before:hover{color:blue} -> priority: 8130
    # This is 3000 (property) + 5000 (::before) + 130 (:hover)
    test "::before:hover pseudo contributes 5130 to total priority" do
      assert Pseudo.calculate_priority("::before:hover") == 5130
    end

    # Combined :hover:active
    # This is additive: 130 + 170 = 300
    test ":hover:active pseudo contributes 300 to total priority" do
      assert Pseudo.calculate_priority(":hover:active") == 300
    end
  end

  # ==========================================================================
  # Public API Accessors
  # ==========================================================================

  describe "public API accessors" do
    test "priorities/0 returns all pseudo-class priorities as tuple list" do
      priorities = Pseudo.priorities()
      assert is_list(priorities)
      # Uses string keys like {":hover", 130}
      assert List.keyfind(priorities, ":hover", 0) == {":hover", 130}
      assert List.keyfind(priorities, ":active", 0) == {":active", 170}
      assert List.keyfind(priorities, ":focus", 0) == {":focus", 150}
    end

    test "priorities/0 contains all StyleX pseudo-classes" do
      priorities = Pseudo.priorities()
      keys = Enum.map(priorities, fn {k, _} -> k end)
      # Verify key pseudo-classes are present
      assert ":hover" in keys
      assert ":focus" in keys
      assert ":active" in keys
      assert ":first-child" in keys
      assert ":last-child" in keys
      assert ":checked" in keys
      assert ":disabled" in keys
    end
  end
end
