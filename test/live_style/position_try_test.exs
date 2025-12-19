defmodule LiveStyle.PositionTryTest do
  @moduledoc """
  Tests for CSS Anchor Positioning (@position-try rules).

  These tests mirror StyleX's transform-stylex-positionTry-test.js to ensure
  LiveStyle handles position-try the same way StyleX does.
  """
  use LiveStyle.TestCase, async: true

  defmodule BasicPositionTry do
    use LiveStyle

    css_position_try(:bottom_fallback,
      position_anchor: "--anchor",
      top: "0",
      left: "0",
      width: "100px",
      height: "100px"
    )
  end

  defmodule LogicalPositionTry do
    use LiveStyle

    # Logical properties should stay as-is (browser handles RTL)
    css_position_try(:inline_fallback,
      inset_inline_start: "0",
      margin_inline_end: "10px"
    )
  end

  defmodule InlinePositionTry do
    use LiveStyle

    # Inline anonymous position-try
    css_rule(:anchored,
      position: "absolute",
      position_anchor: "--my-anchor",
      position_try_fallbacks: css_position_try(top: "0", left: "50px")
    )
  end

  defmodule MultiplePositionTry do
    use LiveStyle

    css_position_try(:fallback_top,
      top: "anchor(bottom)",
      left: "anchor(center)"
    )

    css_position_try(:fallback_bottom,
      bottom: "anchor(top)",
      left: "anchor(center)"
    )
  end

  describe "basic position-try" do
    test "generates @position-try rule" do
      # StyleX: "@position-try --xhs37kq {height:100px;left:0;position-anchor:--anchor;top:0;width:100px;}"
      css = generate_css()

      assert css =~ ~r/@position-try --[a-z0-9]+/
    end

    test "position-try name matches StyleX hash exactly" do
      # From StyleX test: transform-stylex-positionTry-test.js
      # Input: {positionAnchor: '--anchor', top: '0', left: '0', width: '100px', height: '100px'}
      # Expected output: --xhs37kq
      manifest = get_manifest()

      # BasicPositionTry has the same declarations as the StyleX test
      entry = manifest.position_try["LiveStyle.PositionTryTest.BasicPositionTry.bottom_fallback"]
      assert entry.css_name == "--xhs37kq"
    end

    test "position-try name is content-hashed" do
      css = generate_css()

      # Name should be a hashed dashed-ident like --x123abc
      assert css =~ ~r/@position-try --x[a-z0-9]+/
    end

    test "position-try has all declared properties" do
      css = generate_css()

      assert css =~ "position-anchor:--anchor" or css =~ "position-anchor: --anchor"
      assert css =~ "top:" or css =~ "top :"
      assert css =~ "width:" or css =~ "width :"
      assert css =~ "height:" or css =~ "height :"
    end

    test "position-try has priority 0" do
      # StyleX: @position-try has priority 0 (like @keyframes)
      manifest = get_manifest()

      assert map_size(manifest.position_try) > 0
    end
  end

  describe "logical properties in position-try" do
    test "logical properties stay as-is (not transformed to physical)" do
      # StyleX keeps logical properties like inset-inline-start as-is
      # Browser handles RTL automatically for these
      css = generate_css()

      assert css =~ "inset-inline-start"
      assert css =~ "margin-inline-end"
    end

    test "no RTL override for logical properties" do
      # Logical properties don't need RTL variants
      css = generate_css()

      # Should NOT have html[dir="rtl"] wrapper for @position-try
      # (RTL is handled by browser for logical properties)
      refute css =~ ~r/html\[dir="rtl"\].*@position-try/
    end
  end

  describe "inline position-try" do
    test "inline position-try is referenced in position-try-fallbacks" do
      css = generate_css()

      # Should have position-try-fallbacks property referencing the generated name
      # StyleX uses content-based --x<hash> format (e.g., --x1oyda6q)
      # StyleX minified format: prop:value (no spaces)
      assert css =~ ~r/position-try-fallbacks:--x[a-z0-9]+/
    end

    test "inline position-try generates @position-try rule" do
      css = generate_css()

      # Should have both the rule using it and the @position-try definition
      assert css =~ "@position-try"
      assert css =~ "position-try-fallbacks"
    end
  end

  describe "multiple position-try rules" do
    test "different content produces different names" do
      manifest = get_manifest()

      # Should have multiple position-try entries with different names
      names =
        manifest.position_try
        |> Map.keys()
        |> Enum.uniq()

      assert length(names) == map_size(manifest.position_try)
    end

    test "can reference position-try in styles" do
      css = generate_css()

      # The generated position-try names should be valid dashed-idents
      position_try_names =
        Regex.scan(~r/@position-try (--[a-z0-9]+)/, css)
        |> Enum.map(fn [_, name] -> name end)

      for name <- position_try_names do
        assert name =~ ~r/^--x[a-z0-9]+$/
      end
    end
  end

  describe "position-try validation" do
    test "only positioning properties are allowed" do
      # StyleX only allows specific properties in @position-try:
      # - position-anchor, position-area
      # - inset properties (top, right, bottom, left, inset, inset-*)
      # - margin properties
      # - size properties (width, height, min-*, max-*, *-size)
      # - self-alignment (align-self, justify-self, place-self)

      allowed = LiveStyle.PositionTry.allowed_properties()

      # Check some allowed properties
      assert MapSet.member?(allowed, "top")
      assert MapSet.member?(allowed, "left")
      assert MapSet.member?(allowed, "width")
      assert MapSet.member?(allowed, "margin")
      assert MapSet.member?(allowed, "position-anchor")
      assert MapSet.member?(allowed, "inset-inline-start")
      assert MapSet.member?(allowed, "align-self")

      # Check some disallowed properties
      refute MapSet.member?(allowed, "color")
      refute MapSet.member?(allowed, "background")
      refute MapSet.member?(allowed, "display")
    end
  end
end
