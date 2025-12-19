defmodule LiveStyle.KeyframesTest do
  @moduledoc """
  Tests for CSS keyframes.

  These tests mirror StyleX's transform-stylex-keyframes-test.js to ensure
  LiveStyle generates keyframes the same way StyleX does.
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Basic Keyframes
  # ============================================================================

  defmodule BasicKeyframes do
    use LiveStyle

    # StyleX test: "keyframes object"
    # from: { color: 'red' }, to: { color: 'blue' }
    # Expected: name = "x2up61p-B", ltr = "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
    css_keyframes(:color_change,
      from: %{color: "red"},
      to: %{color: "blue"}
    )

    # Simple fade animation
    css_keyframes(:fade,
      from: %{opacity: "0"},
      to: %{opacity: "1"}
    )

    # Rule that references keyframes
    css_class(:animated,
      animation_name: css_keyframes(:fade),
      animation_duration: "1s"
    )
  end

  # ============================================================================
  # Percentage Keyframes
  # ============================================================================

  defmodule PercentageKeyframes do
    use LiveStyle

    css_keyframes(:bounce,
      "0%": %{transform: "translateY(0)"},
      "50%": %{transform: "translateY(-20px)"},
      "100%": %{transform: "translateY(0)"}
    )
  end

  # ============================================================================
  # Inline Keyframes (used directly in animation-name)
  # ============================================================================

  defmodule InlineKeyframes do
    use LiveStyle

    css_keyframes(:pulse,
      from: %{transform: "scale(1)"},
      to: %{transform: "scale(1.1)"}
    )

    css_class(:pulse,
      animation_name: css_keyframes(:pulse),
      animation_duration: "0.5s",
      animation_iteration_count: "infinite"
    )
  end

  # ============================================================================
  # Multiple Properties in Keyframes
  # ============================================================================

  defmodule MultipleProperties do
    use LiveStyle

    css_keyframes(:slide_in,
      from: %{
        opacity: "0",
        transform: "translateX(-100%)"
      },
      to: %{
        opacity: "1",
        transform: "translateX(0)"
      }
    )
  end

  # ============================================================================
  # Comma-Separated Keyframe Keys (StyleX supports "0%, 100%" syntax)
  # ============================================================================

  defmodule CommaSeparatedKeyframes do
    use LiveStyle

    # StyleX supports comma-separated keyframe keys like "0%, 100%"
    # See: packages/benchmarks/size/fixtures/lotsOfStyles.js
    css_keyframes(:pulse_glow,
      "0%, 100%": %{opacity: "1"},
      "50%": %{opacity: "0.5"}
    )

    css_keyframes(:bounce_scale,
      "0%, 100%": %{transform: "scale(1)"},
      "50%": %{transform: "scale(1.2)"}
    )

    # Multiple comma-separated percentages
    css_keyframes(:complex_animation,
      "0%": %{opacity: "0"},
      "25%, 75%": %{opacity: "0.5"},
      "50%": %{opacity: "1"},
      "100%": %{opacity: "0"}
    )
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "keyframes object" do
    test "generates keyframes with exact StyleX output" do
      # StyleX test: transform-stylex-keyframes-test.js "keyframes object"
      # Input: { from: { color: 'red' }, to: { color: 'blue' } }
      # Expected:
      #   name = "x2up61p-B"
      #   ltr = "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
      #   rtl = null
      #   priority = 0
      keyframes = LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :color_change})

      # Exact StyleX hash match
      assert keyframes.css_name == "x2up61p-B"

      # Exact StyleX LTR output match
      assert keyframes.ltr == "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"

      # RTL should be nil for non-RTL properties
      assert keyframes.rtl == nil

      # Priority should be 0 (lowest)
      assert keyframes.priority == 0
    end

    test "keyframes name is content-hashed" do
      fade = LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :fade})
      color_change = LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :color_change})

      # Different content should produce different hashes
      assert fade.css_name != color_change.css_name

      # Both should match the StyleX naming pattern
      assert fade.css_name =~ ~r/^x[a-z0-9]+-B$/
      assert color_change.css_name =~ ~r/^x[a-z0-9]+-B$/
    end
  end

  describe "keyframes referenced in animation-name" do
    test "animation-name references the keyframes name" do
      # StyleX: ".xx2qnu0{animation-name:x2up61p-B}" with priority 3000
      rule = LiveStyle.get_metadata(BasicKeyframes, {:class, :animated})
      keyframes = LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :fade})

      # The animation-name atomic class should reference the keyframes name
      animation_name = rule.atomic_classes["animation-name"]
      assert animation_name.ltr =~ keyframes.css_name
      assert animation_name.ltr =~ ~r/\.x[a-z0-9]+\{animation-name:x[a-z0-9]+-B\}$/
      assert animation_name.priority == 3000
    end
  end

  describe "percentage keyframes" do
    test "supports percentage-based keyframes" do
      keyframes = LiveStyle.get_metadata(PercentageKeyframes, {:keyframes, :bounce})

      # Should have percentage frames in the LTR output
      assert keyframes.ltr =~ "0%{"
      assert keyframes.ltr =~ "50%{"
      assert keyframes.ltr =~ "100%{"

      # Should be compact format
      assert keyframes.ltr =~ ~r/^@keyframes x[a-z0-9]+-B\{/
    end
  end

  describe "inline keyframes" do
    test "inline keyframes are generated and referenced" do
      keyframes = LiveStyle.get_metadata(InlineKeyframes, {:keyframes, :pulse})
      rule = LiveStyle.get_metadata(InlineKeyframes, {:class, :pulse})

      # Keyframes should exist
      assert keyframes.css_name =~ ~r/^x[a-z0-9]+-B$/
      assert keyframes.ltr =~ "@keyframes"

      # Rule should reference the keyframes
      animation_name = rule.atomic_classes["animation-name"]
      assert animation_name.ltr =~ keyframes.css_name
    end
  end

  describe "multiple properties in keyframes" do
    test "keyframes can have multiple properties, sorted alphabetically" do
      # StyleX sorts properties alphabetically within each frame
      keyframes = LiveStyle.get_metadata(MultipleProperties, {:keyframes, :slide_in})

      # Should have both properties
      assert keyframes.ltr =~ "opacity"
      assert keyframes.ltr =~ "transform"

      # Properties should be sorted alphabetically (opacity before transform)
      # In the from frame: opacity:0; comes before transform:translateX(-100%);
      assert keyframes.ltr =~ ~r/from\{opacity:0;transform:translateX\(-100%\);\}/
    end
  end

  describe "keyframes priority" do
    test "keyframes have priority 0" do
      # StyleX: keyframes always have priority 0 (lowest)
      # Test each keyframes module
      assert LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :color_change}).priority == 0
      assert LiveStyle.get_metadata(BasicKeyframes, {:keyframes, :fade}).priority == 0
      assert LiveStyle.get_metadata(PercentageKeyframes, {:keyframes, :bounce}).priority == 0
      assert LiveStyle.get_metadata(InlineKeyframes, {:keyframes, :pulse}).priority == 0
      assert LiveStyle.get_metadata(MultipleProperties, {:keyframes, :slide_in}).priority == 0
    end
  end

  describe "comma-separated keyframe keys" do
    test "supports comma-separated keyframe keys like '0%, 100%'" do
      # StyleX supports this syntax - see lotsOfStyles.js benchmark
      keyframes = LiveStyle.get_metadata(CommaSeparatedKeyframes, {:keyframes, :pulse_glow})

      # Should have the comma-separated key preserved in output
      assert keyframes.ltr =~ "0%, 100%"
      assert keyframes.ltr =~ "50%"
      assert keyframes.ltr =~ "opacity"
    end

    test "frames are sorted by their first percentage value" do
      keyframes = LiveStyle.get_metadata(CommaSeparatedKeyframes, {:keyframes, :pulse_glow})

      # "0%, 100%" should come before "50%" because first value is 0
      # Expected order: "0%, 100%" (sorts by 0), then "50%"
      assert keyframes.ltr =~ ~r/0%, 100%\{.*\}50%\{/
    end

    test "complex animation with multiple comma-separated keys" do
      keyframes =
        LiveStyle.get_metadata(CommaSeparatedKeyframes, {:keyframes, :complex_animation})

      # Should contain all frames
      assert keyframes.ltr =~ "0%{"
      assert keyframes.ltr =~ "25%, 75%"
      assert keyframes.ltr =~ "50%{"
      assert keyframes.ltr =~ "100%{"

      # Frames should be sorted by first percentage: 0%, 25% (from "25%, 75%"), 50%, 100%
      # Regex to verify order
      assert keyframes.ltr =~ ~r/0%\{.*\}25%, 75%\{.*\}50%\{.*\}100%\{/
    end
  end

  describe "frame_sort_order/1" do
    test "handles from/to keywords" do
      assert LiveStyle.Keyframes.frame_sort_order(:from) == 0
      assert LiveStyle.Keyframes.frame_sort_order(:to) == 100
      assert LiveStyle.Keyframes.frame_sort_order("from") == 0
      assert LiveStyle.Keyframes.frame_sort_order("to") == 100
    end

    test "handles percentage strings" do
      assert LiveStyle.Keyframes.frame_sort_order("0%") == 0
      assert LiveStyle.Keyframes.frame_sort_order("25%") == 25
      assert LiveStyle.Keyframes.frame_sort_order("50%") == 50
      assert LiveStyle.Keyframes.frame_sort_order("100%") == 100
    end

    test "handles comma-separated percentages by using first value" do
      assert LiveStyle.Keyframes.frame_sort_order("0%, 100%") == 0
      assert LiveStyle.Keyframes.frame_sort_order("25%, 75%") == 25
      assert LiveStyle.Keyframes.frame_sort_order("50%, 100%") == 50
    end

    test "handles percentage atoms" do
      assert LiveStyle.Keyframes.frame_sort_order(:"0%") == 0
      assert LiveStyle.Keyframes.frame_sort_order(:"50%") == 50
      assert LiveStyle.Keyframes.frame_sort_order(:"100%") == 100
    end

    test "raises on invalid keys" do
      assert_raise ArgumentError, ~r/Invalid keyframe key/, fn ->
        LiveStyle.Keyframes.frame_sort_order("invalid")
      end
    end
  end
end
