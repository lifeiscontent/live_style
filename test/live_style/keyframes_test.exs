defmodule LiveStyle.KeyframesTest do
  @moduledoc """
  Tests for CSS keyframes.

  These tests mirror StyleX's transform-stylex-keyframes-test.js to ensure
  LiveStyle generates keyframes the same way StyleX does.
  """
  use LiveStyle.TestCase
  use Snapshy

  # ============================================================================
  # Basic Keyframes
  # ============================================================================

  defmodule BasicKeyframes do
    use LiveStyle

    # StyleX test: "keyframes object"
    # from: { color: 'red' }, to: { color: 'blue' }
    # Expected: name = "x2up61p-B", ltr = "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
    keyframes(:color_change,
      from: [color: "red"],
      to: [color: "blue"]
    )

    # Simple fade animation
    keyframes(:fade,
      from: [opacity: "0"],
      to: [opacity: "1"]
    )

    # Rule that references keyframes
    class(:animated,
      animation_name: keyframes(:fade),
      animation_duration: "1s"
    )
  end

  # ============================================================================
  # Percentage Keyframes
  # ============================================================================

  defmodule PercentageKeyframes do
    use LiveStyle

    keyframes(:bounce,
      "0%": [transform: "translateY(0)"],
      "50%": [transform: "translateY(-20px)"],
      "100%": [transform: "translateY(0)"]
    )
  end

  # ============================================================================
  # Inline Keyframes (used directly in animation-name)
  # ============================================================================

  defmodule InlineKeyframes do
    use LiveStyle

    keyframes(:pulse,
      from: [transform: "scale(1)"],
      to: [transform: "scale(1.1)"]
    )

    class(:pulse,
      animation_name: keyframes(:pulse),
      animation_duration: "0.5s",
      animation_iteration_count: "infinite"
    )
  end

  # ============================================================================
  # Multiple Properties in Keyframes
  # ============================================================================

  defmodule MultipleProperties do
    use LiveStyle

    # Use keyword lists to preserve insertion order (like StyleX's Object.entries)
    keyframes(:slide_in,
      from: [
        transform: "translateX(-100%)",
        opacity: "0"
      ],
      to: [
        transform: "translateX(0)",
        opacity: "1"
      ]
    )
  end

  # ============================================================================
  # Comma-Separated Keyframe Keys (StyleX supports "0%, 100%" syntax)
  # ============================================================================

  defmodule CommaSeparatedKeyframes do
    use LiveStyle

    # StyleX supports comma-separated keyframe keys like "0%, 100%"
    # See: packages/benchmarks/size/fixtures/lotsOfStyles.js
    keyframes(:pulse_glow,
      "0%, 100%": [opacity: "1"],
      "50%": [opacity: "0.5"]
    )

    keyframes(:bounce_scale,
      "0%, 100%": [transform: "scale(1)"],
      "50%": [transform: "scale(1.2)"]
    )

    # Multiple comma-separated percentages
    keyframes(:complex_animation,
      "0%": [opacity: "0"],
      "25%, 75%": [opacity: "0.5"],
      "50%": [opacity: "1"],
      "100%": [opacity: "0"]
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
      css = LiveStyle.Compiler.generate_css()

      # Should have exact StyleX output format
      assert css =~ "@keyframes x2up61p-B{from{color:red;}to{color:blue;}}"
    end

    test "keyframes names are content-hashed and appear in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Fade keyframes should exist
      assert css =~ ~r/@keyframes x[a-z0-9]+-B\{from\{opacity:0;\}to\{opacity:1;\}\}/

      # Color change keyframes should exist (already tested above)
      assert css =~ ~r/@keyframes x2up61p-B\{from\{color:red;\}to\{color:blue;\}\}/
    end
  end

  describe "keyframes referenced in animation-name" do
    test "animation-name references the keyframes name in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Should have animation-name class that references the fade keyframes
      # Pattern: animation-name with a keyframes reference
      assert css =~ ~r/animation-name:x[a-z0-9]+-B/
    end

    test "animation-duration appears in CSS" do
      css = LiveStyle.Compiler.generate_css()

      assert css =~ "animation-duration:1s"
    end
  end

  describe "percentage keyframes" do
    test "supports percentage-based keyframes in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Should have percentage frames in the keyframes output
      assert css =~ ~r/@keyframes x[a-z0-9]+-B\{0%\{/
      assert css =~ "translateY(-20px)"
      assert css =~ "translateY(0)"
    end
  end

  describe "inline keyframes" do
    test "inline keyframes are generated and referenced in CSS" do
      css = LiveStyle.Compiler.generate_css()

      # Pulse keyframes should exist
      assert css =~
               ~r/@keyframes x[a-z0-9]+-B\{from\{transform:scale\(1\);\}to\{transform:scale\(1\.1\);\}\}/

      # Pulse class should reference the keyframes
      assert css =~ ~r/animation-name:x[a-z0-9]+-B/
      # Note: value is normalized to .5s (no leading zero)
      assert css =~ "animation-duration:.5s"
      assert css =~ "animation-iteration-count:infinite"
    end
  end

  describe "multiple properties in keyframes" do
    test "keyframes can have multiple properties" do
      css = LiveStyle.Compiler.generate_css()

      # Should have keyframes with both opacity and transform
      # Properties are sorted alphabetically for deterministic output across Elixir versions
      assert css =~
               ~r/@keyframes x[a-z0-9]+-B\{from\{opacity:0;transform:translateX\(-100%\);\}to\{opacity:1;transform:translateX\(0\);\}\}/
    end
  end

  describe "keyframes in @keyframes section of CSS" do
    test "all keyframes appear in CSS output" do
      css = LiveStyle.Compiler.generate_css()

      # Count @keyframes rules - should have at least 8 from our test modules
      keyframes_count =
        css
        |> String.split("@keyframes")
        |> length()
        |> Kernel.-(1)

      # BasicKeyframes: 2 (color_change, fade)
      # PercentageKeyframes: 1 (bounce)
      # InlineKeyframes: 1 (pulse)
      # MultipleProperties: 1 (slide_in)
      # CommaSeparatedKeyframes: 3 (pulse_glow, bounce_scale, complex_animation)
      # Total: 8 (some may be deduplicated if content-identical)
      assert keyframes_count >= 6
    end
  end

  describe "comma-separated keyframe keys" do
    test "supports comma-separated keyframe keys like '0%, 100%'" do
      # StyleX supports this syntax - see lotsOfStyles.js benchmark
      css = LiveStyle.Compiler.generate_css()

      # Should have the comma-separated key preserved in output
      assert css =~ "0%, 100%"
      assert css =~ ~r/@keyframes x[a-z0-9]+-B\{0%, 100%\{opacity:1;\}50%\{opacity:0\.5;\}\}/
    end

    test "complex animation with multiple comma-separated keys" do
      css = LiveStyle.Compiler.generate_css()

      # Should contain the complex animation pattern
      # Frames sorted by first percentage: 0%, 25% (from "25%, 75%"), 50%, 100%
      assert css =~
               ~r/@keyframes x[a-z0-9]+-B\{0%\{opacity:0;\}25%, 75%\{opacity:0\.5;\}50%\{opacity:1;\}100%\{opacity:0;\}\}/
    end
  end

  # ============================================================================
  # CSS Output Snapshots
  # ============================================================================

  describe "CSS output snapshots" do
    test_snapshot "all keyframes CSS output" do
      css = LiveStyle.Compiler.generate_css()

      # Extract all @keyframes rules
      css
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "@keyframes"))
      |> Enum.sort()
      |> Enum.join("\n")
    end

    test_snapshot "animation classes CSS output" do
      css = LiveStyle.Compiler.generate_css()

      # Extract all animation-related classes
      css
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.contains?(line, "animation-") and String.starts_with?(line, ".")
      end)
      |> Enum.sort()
      |> Enum.join("\n")
    end
  end
end
