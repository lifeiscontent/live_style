defmodule LiveStyle.PriorityLayersTest do
  @moduledoc """
  Tests for CSS priority layers feature.

  When `use_priority_layers: true` is set, LiveStyle groups CSS rules
  by priority level into separate `@layer priorityN` blocks, matching
  StyleX's `useLayers: true` behavior.

  Note: This test runs with async: false because it needs to modify
  global config (use_priority_layers, use_css_layers) that affects
  CSS generation for the entire manifest.
  """
  use LiveStyle.TestCase, async: false

  # ============================================================================
  # Test Modules - Define styles with different priority levels
  # ============================================================================

  defmodule BasicStyles do
    use LiveStyle

    # Priority 3000 - regular property
    css_class(:color_style, color: "red")

    # Priority 3000 - another regular property
    css_class(:background_style, background_color: "blue")

    # Priority 1000 - shorthand (margin is shorthand of shorthands)
    css_class(:margin_style, margin: "10px")

    # Priority 4000 - physical longhand
    css_class(:margin_top_style, margin_top: "5px")
  end

  defmodule PseudoStyles do
    use LiveStyle

    # Priority 3000 + pseudo offset
    css_class(:hover_style, color: [default: "blue", ":hover": "red"])
  end

  defmodule MediaQueryStyles do
    use LiveStyle

    # Priority 3000 + at-rule offset
    css_class(:responsive_style,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": "2rem"
      ]
    )
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "use_priority_layers: false (default)" do
    test "wraps all rules in single @layer live_style block" do
      # Default behavior - single @layer wrapper
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Should have single @layer live_style wrapper
      assert css =~ "@layer live_style {"
      # Should NOT have @layer priority blocks
      refute css =~ ~r/@layer priority\d+\{/
    end
  end

  describe "use_priority_layers: true" do
    setup do
      LiveStyle.Config.put(:use_priority_layers, true)
      on_exit(fn -> LiveStyle.Config.reset(:use_priority_layers) end)
      :ok
    end

    test "generates @layer declaration header" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Should have layer declaration header
      assert css =~ ~r/@layer priority\d+(, priority\d+)*;/
    end

    test "groups rules by priority level into @layer blocks" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Should have @layer priorityN blocks (with curly brace, not just semicolon)
      assert css =~ ~r/@layer priority\d+\{/
    end

    test "different priorities result in multiple layers" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Count unique priority layer numbers in the output
      layer_matches = Regex.scan(~r/@layer priority(\d+)\{/, css)
      layer_numbers = Enum.map(layer_matches, fn [_, n] -> String.to_integer(n) end)
      unique_layers = Enum.uniq(layer_numbers)

      # Should have multiple different priority layers (from different priority levels)
      assert length(unique_layers) > 1,
             "Expected multiple priority layers, got: #{inspect(unique_layers)}"
    end

    test "layer declaration lists all layers in ascending order" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Extract layer declaration (should be first @layer statement with semicolon)
      case Regex.run(~r/@layer [^;]+;/, css) do
        [declaration] ->
          # Extract layer names from declaration
          layer_names = Regex.scan(~r/priority(\d+)/, declaration)
          layer_numbers = Enum.map(layer_names, fn [_, n] -> String.to_integer(n) end)

          # Should be in ascending order
          assert layer_numbers == Enum.sort(layer_numbers),
                 "Layer declaration should be in ascending order, got: #{inspect(layer_numbers)}"

        nil ->
          flunk("No layer declaration found in CSS")
      end
    end

    test "rules from this test module are included in CSS" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Verify our test module's rules are in the generated CSS
      # StyleX uses minified format: .class{prop:value}
      # color:red from BasicStyles.color_style
      assert css =~ "color:red"
      # background-color:blue from BasicStyles.background_style
      assert css =~ "background-color:blue"
      # margin from BasicStyles.margin_style
      assert css =~ "margin:10px"
    end
  end

  describe "priority layer grouping" do
    setup do
      LiveStyle.Config.put(:use_priority_layers, true)
      on_exit(fn -> LiveStyle.Config.reset(:use_priority_layers) end)
      :ok
    end

    test "shorthand properties appear in earlier layers than longhands" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Find which layer margin:10px is in (shorthand, priority ~1000)
      margin_layer_match = Regex.run(~r/@layer priority(\d+)\{[^}]*margin:10px/s, css)

      # Find which layer margin-top:5px is in (longhand, priority ~4000)
      margin_top_layer_match = Regex.run(~r/@layer priority(\d+)\{[^}]*margin-top:5px/s, css)

      if margin_layer_match && margin_top_layer_match do
        [_, margin_layer_str] = margin_layer_match
        [_, margin_top_layer_str] = margin_top_layer_match
        margin_layer = String.to_integer(margin_layer_str)
        margin_top_layer = String.to_integer(margin_top_layer_str)

        assert margin_layer < margin_top_layer,
               "margin (layer #{margin_layer}) should be in earlier layer than margin-top (layer #{margin_top_layer})"
      else
        # If we can't find one or both, just check the order in the string
        margin_pos = :binary.match(css, "margin:10px") |> elem(0)
        margin_top_pos = :binary.match(css, "margin-top:5px") |> elem(0)

        assert margin_pos < margin_top_pos,
               "margin should appear before margin-top in CSS output"
      end
    end
  end

  describe "interaction with use_css_layers: false" do
    setup do
      LiveStyle.Config.put(:use_css_layers, false)
      LiveStyle.Config.put(:use_priority_layers, true)

      on_exit(fn ->
        LiveStyle.Config.reset(:use_css_layers)
        LiveStyle.Config.reset(:use_priority_layers)
      end)

      :ok
    end

    test "priority layers are ignored when use_css_layers is false" do
      manifest = get_manifest()
      css = LiveStyle.CSS.generate(manifest)

      # Should NOT have @layer priority blocks (priority layers need css layers enabled)
      refute css =~ ~r/@layer priority\d+\{/

      # Should NOT have @layer live_style wrapper either
      refute css =~ "@layer live_style"

      # Should have rules without wrapper - verify our test styles are present
      assert css =~ "color:red"
      assert css =~ "background-color:blue"
    end
  end

  describe "config documentation" do
    test "use_priority_layers? defaults to false" do
      # Reset any overrides
      LiveStyle.Config.reset(:use_priority_layers)

      assert LiveStyle.Config.use_priority_layers?() == false
    end

    test "use_priority_layers? can be set via config override" do
      LiveStyle.Config.put(:use_priority_layers, true)
      assert LiveStyle.Config.use_priority_layers?() == true

      LiveStyle.Config.put(:use_priority_layers, false)
      assert LiveStyle.Config.use_priority_layers?() == false
    end
  end
end
