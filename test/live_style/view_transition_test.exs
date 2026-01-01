defmodule LiveStyle.ViewTransitionTest do
  @moduledoc """
  Tests for LiveStyle's view_transition_class macro.

  These tests verify that LiveStyle's view transition implementation matches StyleX's
  viewTransitionClass API behavior.

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-viewTransitionClass-test.js
  """
  use LiveStyle.TestCase
  use Snapshy

  # ===========================================================================
  # Basic view transition tests
  # ===========================================================================

  describe "basic view transitions" do
    defmodule BasicViewTransition do
      use LiveStyle

      view_transition_class(:card,
        group: [transition_property: "none"],
        image_pair: [border_radius: 16],
        old: [animation_duration: "0.5s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test_snapshot "view transition with all pseudo-element types CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition = LiveStyle.ViewTransition.lookup!({BasicViewTransition, :card})
      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "generates view transition with all pseudo-element types" do
      view_transition = LiveStyle.ViewTransition.lookup!({BasicViewTransition, :card})

      assert view_transition != nil
      assert view_transition.ident != nil
      assert is_binary(view_transition.ident)

      # Should have styles for all four pseudo-element types
      assert Keyword.has_key?(view_transition.styles, :group)
      assert Keyword.has_key?(view_transition.styles, :image_pair)
      assert Keyword.has_key?(view_transition.styles, :old)
      assert Keyword.has_key?(view_transition.styles, :new)
    end

    defmodule GroupOnlyViewTransition do
      use LiveStyle

      view_transition_class(:slide,
        group: [animation_duration: "1s"]
      )
    end

    test_snapshot "view transition with only group pseudo-element CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition = LiveStyle.ViewTransition.lookup!({GroupOnlyViewTransition, :slide})
      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "handles view transition with only group pseudo-element" do
      view_transition = LiveStyle.ViewTransition.lookup!({GroupOnlyViewTransition, :slide})

      assert view_transition != nil
      assert view_transition.ident != nil
      assert Keyword.has_key?(view_transition.styles, :group)
      refute Keyword.has_key?(view_transition.styles, :image_pair)
      refute Keyword.has_key?(view_transition.styles, :old)
      refute Keyword.has_key?(view_transition.styles, :new)
    end

    defmodule ImagePairOnlyViewTransition do
      use LiveStyle

      view_transition_class(:image,
        image_pair: [isolation: "isolate"]
      )
    end

    test "handles view transition with only image_pair pseudo-element" do
      view_transition = LiveStyle.ViewTransition.lookup!({ImagePairOnlyViewTransition, :image})

      assert view_transition != nil
      assert Keyword.has_key?(view_transition.styles, :image_pair)
    end

    defmodule OldOnlyViewTransition do
      use LiveStyle

      view_transition_class(:fade_out,
        old: [animation_name: "fadeOut", animation_duration: "0.3s"]
      )
    end

    test "handles view transition with only old pseudo-element" do
      view_transition = LiveStyle.ViewTransition.lookup!({OldOnlyViewTransition, :fade_out})

      assert view_transition != nil
      assert Keyword.has_key?(view_transition.styles, :old)
    end

    defmodule NewOnlyViewTransition do
      use LiveStyle

      view_transition_class(:fade_in,
        new: [animation_name: "fadeIn", animation_duration: "0.3s"]
      )
    end

    test "handles view transition with only new pseudo-element" do
      view_transition = LiveStyle.ViewTransition.lookup!({NewOnlyViewTransition, :fade_in})

      assert view_transition != nil
      assert Keyword.has_key?(view_transition.styles, :new)
    end
  end

  # ===========================================================================
  # View transitions with keyframes
  # ===========================================================================

  describe "view transitions with keyframes" do
    defmodule ViewTransitionWithKeyframes do
      use LiveStyle

      keyframes(:fade_in,
        from: [opacity: 0],
        to: [opacity: 1]
      )

      keyframes(:fade_out,
        from: [opacity: 1],
        to: [opacity: 0]
      )

      view_transition_class(:crossfade,
        old: [animation_name: keyframes(:fade_out), animation_duration: "1s"],
        new: [animation_name: keyframes(:fade_in), animation_duration: "1s"]
      )
    end

    test_snapshot "view transition with keyframes CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionWithKeyframes, :crossfade})

      ident = view_transition.ident

      # Include keyframes and view transition rules
      keyframes_fade_in =
        LiveStyle.Keyframes.lookup!({ViewTransitionWithKeyframes, :fade_in})

      keyframes_fade_out =
        LiveStyle.Keyframes.lookup!({ViewTransitionWithKeyframes, :fade_out})

      vt_rules = extract_view_transition_rules(css, ident)
      kf_rules_in = extract_keyframes_rules(css, keyframes_fade_in.ident)
      kf_rules_out = extract_keyframes_rules(css, keyframes_fade_out.ident)

      (vt_rules ++ kf_rules_in ++ kf_rules_out)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "uses keyframe references in view transition" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionWithKeyframes, :crossfade})

      assert view_transition != nil

      # Verify keyframes are also registered
      fade_in = LiveStyle.Keyframes.lookup!({ViewTransitionWithKeyframes, :fade_in})
      fade_out = LiveStyle.Keyframes.lookup!({ViewTransitionWithKeyframes, :fade_out})

      assert fade_in != nil
      assert fade_out != nil
    end

    defmodule ViewTransitionWithSlideKeyframes do
      use LiveStyle

      keyframes(:slide_in,
        from: [transform: "translateX(100%)"],
        to: [transform: "translateX(0)"]
      )

      keyframes(:slide_out,
        from: [transform: "translateX(0)"],
        to: [transform: "translateX(-100%)"]
      )

      view_transition_class(:slide,
        old: [animation_name: keyframes(:slide_out), animation_duration: "0.5s"],
        new: [animation_name: keyframes(:slide_in), animation_duration: "0.5s"]
      )
    end

    test "view transition with transform keyframes" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionWithSlideKeyframes, :slide})

      assert view_transition != nil
      assert Keyword.has_key?(view_transition.styles, :old)
      assert Keyword.has_key?(view_transition.styles, :new)
    end
  end

  # ===========================================================================
  # View transitions with multiple properties
  # ===========================================================================

  describe "view transitions with multiple properties" do
    defmodule ViewTransitionMultipleProps do
      use LiveStyle

      view_transition_class(:complex,
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

    test_snapshot "complex view transition with multiple properties CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionMultipleProps, :complex})

      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "handles multiple properties per pseudo-element" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionMultipleProps, :complex})

      assert view_transition != nil

      # Group should have 2 properties
      assert length(view_transition.styles[:group]) == 2

      # Image pair should have 2 properties
      assert length(view_transition.styles[:image_pair]) == 2

      # Old should have 2 properties
      assert length(view_transition.styles[:old]) == 2

      # New should have 2 properties
      assert length(view_transition.styles[:new]) == 2
    end
  end

  # ===========================================================================
  # View transition value normalization
  # ===========================================================================

  describe "value normalization" do
    defmodule ViewTransitionValueNormalization do
      use LiveStyle

      view_transition_class(:normalized,
        group: [
          animation_duration: 500
        ],
        image_pair: [
          border_radius: 16
        ]
      )
    end

    test "stores values in styles map" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionValueNormalization, :normalized})

      assert view_transition != nil

      # Check that border_radius value is stored
      image_pair_styles = view_transition.styles[:image_pair]
      assert Keyword.has_key?(image_pair_styles, :border_radius)
    end

    defmodule ViewTransitionStringValues do
      use LiveStyle

      view_transition_class(:string_vals,
        old: [
          animation_duration: "0.5s",
          animation_timing_function: "cubic-bezier(0.4, 0, 0.2, 1)"
        ]
      )
    end

    test "preserves string values" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionStringValues, :string_vals})

      assert view_transition != nil

      old_styles = view_transition.styles[:old]

      assert Keyword.get(old_styles, :animation_timing_function) ==
               "cubic-bezier(0.4, 0, 0.2, 1)"
    end
  end

  # ===========================================================================
  # view_transition_class/1 - reference syntax
  # ===========================================================================

  describe "view transition reference syntax" do
    defmodule ViewTransitionDefinition do
      use LiveStyle

      view_transition_class(:my_transition,
        group: [animation_duration: "0.3s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test "can get view transition name from module" do
      vt = LiveStyle.ViewTransition.lookup!({ViewTransitionDefinition, :my_transition})

      assert is_binary(vt.ident)
      assert vt.ident != ""
    end
  end

  # ===========================================================================
  # Multiple view transitions in same module
  # ===========================================================================

  describe "multiple view transitions" do
    defmodule MultipleViewTransitions do
      use LiveStyle

      view_transition_class(:fade,
        old: [animation_name: "fadeOut"],
        new: [animation_name: "fadeIn"]
      )

      view_transition_class(:slide,
        old: [animation_name: "slideOut"],
        new: [animation_name: "slideIn"]
      )

      view_transition_class(:scale,
        group: [animation_duration: "0.5s"],
        old: [transform: "scale(1.1)"],
        new: [transform: "scale(0.9)"]
      )
    end

    test_snapshot "multiple view transitions CSS output" do
      css = LiveStyle.Compiler.generate_css()

      fade = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :fade})
      slide = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :slide})
      scale = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :scale})

      fade_rules = extract_view_transition_rules(css, fade.ident)
      slide_rules = extract_view_transition_rules(css, slide.ident)
      scale_rules = extract_view_transition_rules(css, scale.ident)

      (fade_rules ++ slide_rules ++ scale_rules)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "each view transition gets unique name" do
      fade = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :fade})
      slide = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :slide})
      scale = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :scale})

      assert fade.ident != slide.ident
      assert slide.ident != scale.ident
      assert fade.ident != scale.ident
    end

    test "all view transitions are registered in manifest" do
      fade = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :fade})
      slide = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :slide})
      scale = LiveStyle.ViewTransition.lookup!({MultipleViewTransitions, :scale})

      assert fade != nil
      assert slide != nil
      assert scale != nil
    end
  end

  # ===========================================================================
  # CSS output format (via LiveStyle.CSS)
  # ===========================================================================

  describe "CSS output format" do
    defmodule ViewTransitionCSSFormat do
      use LiveStyle

      view_transition_class(:format_test,
        group: [transition_property: "none"],
        image_pair: [border_radius: 8],
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test_snapshot "CSS format with view transition pseudo-elements" do
      css = LiveStyle.Compiler.generate_css()

      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionCSSFormat, :format_test})

      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "generates CSS with view transition pseudo-elements" do
      # Generate CSS output
      css = LiveStyle.Compiler.generate_css()

      # The CSS should contain view-transition pseudo-elements
      assert css =~ "::view-transition-group"
      assert css =~ "::view-transition-image-pair"
      assert css =~ "::view-transition-old"
      assert css =~ "::view-transition-new"
    end

    test "CSS uses wildcard class selector pattern" do
      css = LiveStyle.Compiler.generate_css()

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

      view_transition_class(:zero_values,
        group: [animation_delay: 0],
        old: [opacity: 0]
      )
    end

    test "handles zero values" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionWithZero, :zero_values})

      assert view_transition != nil

      # Zero opacity should be stored
      assert Keyword.get(view_transition.styles[:old], :opacity) == 0
    end

    defmodule ViewTransitionEmptyGroup do
      use LiveStyle

      # Only old and new, no group or image_pair
      view_transition_class(:minimal,
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test_snapshot "minimal view transition CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionEmptyGroup, :minimal})

      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "handles transition without group or image_pair" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionEmptyGroup, :minimal})

      assert view_transition != nil

      # Should only have old and new
      assert Keyword.has_key?(view_transition.styles, :old)
      assert Keyword.has_key?(view_transition.styles, :new)
      refute Keyword.has_key?(view_transition.styles, :group)
      refute Keyword.has_key?(view_transition.styles, :image_pair)
    end

    defmodule ViewTransitionCSSMinimalOutput do
      use LiveStyle

      view_transition_class(:css_minimal,
        old: [opacity: 0],
        new: [opacity: 1]
      )
    end

    test "CSS output does not include unspecified pseudo-elements" do
      view_transition =
        LiveStyle.ViewTransition.lookup!({ViewTransitionCSSMinimalOutput, :css_minimal})

      ident = view_transition.ident
      css = LiveStyle.Compiler.generate_css()

      # Should have old and new
      assert css =~ "::view-transition-old(*.#{ident})"
      assert css =~ "::view-transition-new(*.#{ident})"

      # Should NOT have group or image_pair for this specific class
      # (They might exist from other tests, so we check the specific pattern)
      refute css =~ "::view-transition-group(*.#{ident})"
      refute css =~ "::view-transition-image-pair(*.#{ident})"
    end
  end

  # ===========================================================================
  # StyleX parity - hash consistency
  # ===========================================================================

  describe "StyleX parity" do
    defmodule StyleXParityBasic do
      use LiveStyle

      # Matches StyleX test: "viewTransitionClass basic object"
      view_transition_class(:test,
        group: [transition_property: "none"],
        image_pair: [border_radius: 16],
        old: [animation_duration: "0.5s"],
        new: [animation_timing_function: "ease-out"]
      )
    end

    test_snapshot "StyleX parity basic view transition CSS output" do
      css = LiveStyle.Compiler.generate_css()

      view_transition = LiveStyle.ViewTransition.lookup!({StyleXParityBasic, :test})
      ident = view_transition.ident

      css
      |> extract_view_transition_rules(ident)
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test "matches StyleX hash for basic view transition" do
      # Expected StyleX output: "xchu1hv"
      view_transition = LiveStyle.ViewTransition.lookup!({StyleXParityBasic, :test})

      assert view_transition.ident == "xchu1hv"
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp extract_view_transition_rules(css, ident) do
    escaped_ident = Regex.escape(ident)

    # Pattern for view-transition pseudo-elements: ::view-transition-group(*.xident){...}
    patterns = [
      ~r/::view-transition-group\(\*\.#{escaped_ident}\)\{[^}]+\}/,
      ~r/::view-transition-image-pair\(\*\.#{escaped_ident}\)\{[^}]+\}/,
      ~r/::view-transition-old\(\*\.#{escaped_ident}\)\{[^}]+\}/,
      ~r/::view-transition-new\(\*\.#{escaped_ident}\)\{[^}]+\}/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, css) |> List.flatten()
    end)
  end

  defp extract_keyframes_rules(css, ident) do
    escaped_ident = Regex.escape(ident)

    pattern = ~r/@keyframes #{escaped_ident}-B\{[^}]+(?:\{[^}]*\}[^}]*)+\}/

    Regex.scan(pattern, css) |> List.flatten()
  end
end
