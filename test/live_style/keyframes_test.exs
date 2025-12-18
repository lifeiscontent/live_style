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
    css_rule(:animated,
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

    css_rule(:pulse,
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
      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.KeyframesTest.BasicKeyframes.color_change"]

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
      manifest = get_manifest()

      fade = manifest.keyframes["LiveStyle.KeyframesTest.BasicKeyframes.fade"]
      color_change = manifest.keyframes["LiveStyle.KeyframesTest.BasicKeyframes.color_change"]

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
      manifest = get_manifest()
      rule = manifest.rules["LiveStyle.KeyframesTest.BasicKeyframes.animated"]
      keyframes = manifest.keyframes["LiveStyle.KeyframesTest.BasicKeyframes.fade"]

      # The animation-name atomic class should reference the keyframes name
      animation_name = rule.atomic_classes["animation-name"]
      assert animation_name.ltr =~ keyframes.css_name
      assert animation_name.ltr =~ ~r/\.x[a-z0-9]+\{animation-name:x[a-z0-9]+-B\}$/
      assert animation_name.priority == 3000
    end
  end

  describe "percentage keyframes" do
    test "supports percentage-based keyframes" do
      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.KeyframesTest.PercentageKeyframes.bounce"]

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
      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.KeyframesTest.InlineKeyframes.pulse"]
      rule = manifest.rules["LiveStyle.KeyframesTest.InlineKeyframes.pulse"]

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
      manifest = get_manifest()
      keyframes = manifest.keyframes["LiveStyle.KeyframesTest.MultipleProperties.slide_in"]

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
      manifest = get_manifest()

      Enum.each(manifest.keyframes, fn {_key, keyframes} ->
        assert keyframes.priority == 0
      end)
    end
  end
end
