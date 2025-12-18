defmodule LiveStyle.ViewTransitionTest do
  @moduledoc """
  Tests for LiveStyle's css_view_transition macro.

  These tests verify that LiveStyle's view transition implementation matches StyleX's
  viewTransitionClass API behavior.

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-viewTransitionClass-test.js
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Basic view transition tests
  # ===========================================================================

  describe "basic view transitions" do
    defmodule BasicViewTransition do
      use LiveStyle

      css_view_transition(:card,
        group: [transition_property: "none"],
        image_pair: [border_radius: 16],
        old: [animation_duration: "0.5s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test "generates view transition with all pseudo-element types" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.BasicViewTransition.card"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert view_transition.css_name != nil
      assert is_binary(view_transition.css_name)

      # Should have styles for all four pseudo-element types
      assert Map.has_key?(view_transition.styles, :group)
      assert Map.has_key?(view_transition.styles, :image_pair)
      assert Map.has_key?(view_transition.styles, :old)
      assert Map.has_key?(view_transition.styles, :new)
    end

    defmodule GroupOnlyViewTransition do
      use LiveStyle

      css_view_transition(:slide,
        group: [animation_duration: "1s"]
      )
    end

    test "handles view transition with only group pseudo-element" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.GroupOnlyViewTransition.slide"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert view_transition.css_name != nil
      assert Map.has_key?(view_transition.styles, :group)
      refute Map.has_key?(view_transition.styles, :image_pair)
      refute Map.has_key?(view_transition.styles, :old)
      refute Map.has_key?(view_transition.styles, :new)
    end

    defmodule ImagePairOnlyViewTransition do
      use LiveStyle

      css_view_transition(:image,
        image_pair: [isolation: "isolate"]
      )
    end

    test "handles view transition with only image_pair pseudo-element" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ImagePairOnlyViewTransition.image"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert Map.has_key?(view_transition.styles, :image_pair)
    end

    defmodule OldOnlyViewTransition do
      use LiveStyle

      css_view_transition(:fade_out,
        old: [animation_name: "fadeOut", animation_duration: "0.3s"]
      )
    end

    test "handles view transition with only old pseudo-element" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.OldOnlyViewTransition.fade_out"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert Map.has_key?(view_transition.styles, :old)
    end

    defmodule NewOnlyViewTransition do
      use LiveStyle

      css_view_transition(:fade_in,
        new: [animation_name: "fadeIn", animation_duration: "0.3s"]
      )
    end

    test "handles view transition with only new pseudo-element" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.NewOnlyViewTransition.fade_in"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert Map.has_key?(view_transition.styles, :new)
    end
  end

  # ===========================================================================
  # View transitions with keyframes
  # ===========================================================================

  describe "view transitions with keyframes" do
    defmodule ViewTransitionWithKeyframes do
      use LiveStyle

      css_keyframes(:fade_in,
        from: %{opacity: 0},
        to: %{opacity: 1}
      )

      css_keyframes(:fade_out,
        from: %{opacity: 1},
        to: %{opacity: 0}
      )

      css_view_transition(:crossfade,
        old: [animation_name: css_keyframes(:fade_out), animation_duration: "1s"],
        new: [animation_name: css_keyframes(:fade_in), animation_duration: "1s"]
      )
    end

    test "uses keyframe references in view transition" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionWithKeyframes.crossfade"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      # Verify keyframes are also registered
      fade_in_key = "LiveStyle.ViewTransitionTest.ViewTransitionWithKeyframes.fade_in"
      fade_out_key = "LiveStyle.ViewTransitionTest.ViewTransitionWithKeyframes.fade_out"

      fade_in = LiveStyle.Manifest.get_keyframes(manifest, fade_in_key)
      fade_out = LiveStyle.Manifest.get_keyframes(manifest, fade_out_key)

      assert fade_in != nil
      assert fade_out != nil
    end

    defmodule ViewTransitionWithSlideKeyframes do
      use LiveStyle

      css_keyframes(:slide_in,
        from: %{transform: "translateX(100%)"},
        to: %{transform: "translateX(0)"}
      )

      css_keyframes(:slide_out,
        from: %{transform: "translateX(0)"},
        to: %{transform: "translateX(-100%)"}
      )

      css_view_transition(:slide,
        old: [animation_name: css_keyframes(:slide_out), animation_duration: "0.5s"],
        new: [animation_name: css_keyframes(:slide_in), animation_duration: "0.5s"]
      )
    end

    test "view transition with transform keyframes" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionWithSlideKeyframes.slide"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil
      assert Map.has_key?(view_transition.styles, :old)
      assert Map.has_key?(view_transition.styles, :new)
    end
  end

  # ===========================================================================
  # View transitions with multiple properties
  # ===========================================================================

  describe "view transitions with multiple properties" do
    defmodule ViewTransitionMultipleProps do
      use LiveStyle

      css_view_transition(:complex,
        group: [
          animation_duration: "0.3s",
          animation_timing_function: "ease-in-out"
        ],
        image_pair: [
          border_radius: 8,
          overflow: "hidden"
        ],
        old: [
          animation_duration: "0.3s",
          animation_fill_mode: "forwards"
        ],
        new: [
          animation_duration: "0.3s",
          animation_fill_mode: "backwards"
        ]
      )
    end

    test "handles multiple properties per pseudo-element" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionMultipleProps.complex"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      # Group should have 2 properties
      assert length(view_transition.styles.group) == 2

      # Image pair should have 2 properties
      assert length(view_transition.styles.image_pair) == 2

      # Old should have 2 properties
      assert length(view_transition.styles.old) == 2

      # New should have 2 properties
      assert length(view_transition.styles.new) == 2
    end
  end

  # ===========================================================================
  # View transition value normalization
  # ===========================================================================

  describe "value normalization" do
    defmodule ViewTransitionValueNormalization do
      use LiveStyle

      css_view_transition(:normalized,
        group: [
          animation_duration: 500
        ],
        image_pair: [
          border_radius: 16
        ]
      )
    end

    test "stores values in styles map" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionValueNormalization.normalized"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      # Check that border_radius value is stored
      image_pair_styles = view_transition.styles.image_pair
      assert Keyword.has_key?(image_pair_styles, :border_radius)
    end

    defmodule ViewTransitionStringValues do
      use LiveStyle

      css_view_transition(:string_vals,
        old: [
          animation_duration: "0.5s",
          animation_timing_function: "cubic-bezier(0.4, 0, 0.2, 1)"
        ]
      )
    end

    test "preserves string values" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionStringValues.string_vals"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      old_styles = view_transition.styles.old

      assert Keyword.get(old_styles, :animation_timing_function) ==
               "cubic-bezier(0.4, 0, 0.2, 1)"
    end
  end

  # ===========================================================================
  # css_view_transition/1 - reference syntax
  # ===========================================================================

  describe "view transition reference syntax" do
    defmodule ViewTransitionDefinition do
      use LiveStyle

      css_view_transition(:my_transition,
        group: [animation_duration: "0.3s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test "can get view transition name from module" do
      name = LiveStyle.ViewTransition.lookup!(ViewTransitionDefinition, :my_transition)

      assert is_binary(name)
      assert name != ""
    end
  end

  # ===========================================================================
  # Multiple view transitions in same module
  # ===========================================================================

  describe "multiple view transitions" do
    defmodule MultipleViewTransitions do
      use LiveStyle

      css_view_transition(:fade,
        old: [animation_name: "fadeOut"],
        new: [animation_name: "fadeIn"]
      )

      css_view_transition(:slide,
        old: [animation_name: "slideOut"],
        new: [animation_name: "slideIn"]
      )

      css_view_transition(:scale,
        group: [animation_duration: "0.5s"],
        old: [transform: "scale(1.1)"],
        new: [transform: "scale(0.9)"]
      )
    end

    test "each view transition gets unique name" do
      fade_name = LiveStyle.ViewTransition.lookup!(MultipleViewTransitions, :fade)
      slide_name = LiveStyle.ViewTransition.lookup!(MultipleViewTransitions, :slide)
      scale_name = LiveStyle.ViewTransition.lookup!(MultipleViewTransitions, :scale)

      assert fade_name != slide_name
      assert slide_name != scale_name
      assert fade_name != scale_name
    end

    test "all view transitions are registered in manifest" do
      manifest = get_manifest()

      fade_key = "LiveStyle.ViewTransitionTest.MultipleViewTransitions.fade"
      slide_key = "LiveStyle.ViewTransitionTest.MultipleViewTransitions.slide"
      scale_key = "LiveStyle.ViewTransitionTest.MultipleViewTransitions.scale"

      assert LiveStyle.Manifest.get_view_transition(manifest, fade_key) != nil
      assert LiveStyle.Manifest.get_view_transition(manifest, slide_key) != nil
      assert LiveStyle.Manifest.get_view_transition(manifest, scale_key) != nil
    end
  end

  # ===========================================================================
  # CSS output format (via LiveStyle.CSS)
  # ===========================================================================

  describe "CSS output format" do
    defmodule ViewTransitionCSSFormat do
      use LiveStyle

      css_view_transition(:format_test,
        group: [transition_property: "none"],
        image_pair: [border_radius: 8],
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test "generates CSS with view transition pseudo-elements" do
      # Generate CSS output
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # The CSS should contain view-transition pseudo-elements
      assert css =~ "::view-transition-group"
      assert css =~ "::view-transition-image-pair"
      assert css =~ "::view-transition-old"
      assert css =~ "::view-transition-new"
    end

    test "CSS uses wildcard class selector pattern" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # StyleX pattern: ::view-transition-group(*.xchu1hv)
      assert css =~ ~r/::view-transition-\w+\(\*\.x[a-z0-9]+\)/
    end
  end

  # ===========================================================================
  # Edge cases
  # ===========================================================================

  describe "edge cases" do
    defmodule ViewTransitionWithZero do
      use LiveStyle

      css_view_transition(:zero_values,
        group: [animation_delay: 0],
        old: [opacity: 0]
      )
    end

    test "handles zero values" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionWithZero.zero_values"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      # Zero opacity should be stored
      assert Keyword.get(view_transition.styles.old, :opacity) == 0
    end

    defmodule ViewTransitionEmptyGroup do
      use LiveStyle

      # Only old and new, no group or image_pair
      css_view_transition(:minimal,
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test "handles transition without group or image_pair" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionEmptyGroup.minimal"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition != nil

      # Should only have old and new
      assert Map.has_key?(view_transition.styles, :old)
      assert Map.has_key?(view_transition.styles, :new)
      refute Map.has_key?(view_transition.styles, :group)
      refute Map.has_key?(view_transition.styles, :image_pair)
    end

    defmodule ViewTransitionCSSMinimalOutput do
      use LiveStyle

      css_view_transition(:css_minimal,
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test "CSS output does not include unspecified pseudo-elements" do
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.ViewTransitionCSSMinimalOutput.css_minimal"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)
      css_name = view_transition.css_name

      css = LiveStyle.CSS.generate(manifest)

      # Should have old and new
      assert css =~ "::view-transition-old(*.#{css_name})"
      assert css =~ "::view-transition-new(*.#{css_name})"

      # Should NOT have group or image_pair for this specific class
      # (They might exist from other tests, so we check the specific pattern)
      refute css =~ "::view-transition-group(*.#{css_name})"
      refute css =~ "::view-transition-image-pair(*.#{css_name})"
    end
  end

  # ===========================================================================
  # StyleX parity - hash consistency
  # ===========================================================================

  describe "StyleX parity" do
    defmodule StyleXParityBasic do
      use LiveStyle

      # Matches StyleX test: "viewTransitionClass basic object"
      css_view_transition(:test,
        group: [transition_property: "none"],
        image_pair: [border_radius: 16],
        old: [animation_duration: "0.5s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test "matches StyleX hash for basic view transition" do
      # Expected StyleX output: "xchu1hv"
      manifest = get_manifest()
      full_key = "LiveStyle.ViewTransitionTest.StyleXParityBasic.test"
      view_transition = LiveStyle.Manifest.get_view_transition(manifest, full_key)

      assert view_transition.css_name == "xchu1hv"
    end
  end
end
