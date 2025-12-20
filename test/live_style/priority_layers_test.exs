defmodule LiveStyle.PriorityLayersTest do
  @moduledoc """
  Tests for CSS layers feature.

  When `use_css_layers: true` is set, LiveStyle groups CSS rules
  by priority level into separate `@layer priorityN` blocks, matching
  StyleX's `useLayers: true` behavior.

  When `use_css_layers: false` (default), LiveStyle uses the `:not(#\\#)`
  selector hack for specificity bumping, matching StyleX's default behavior.

  Note: This test runs with async: false because it needs to modify
  global config (use_css_layers) that affects CSS generation for the
  entire manifest.
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

  describe "use_css_layers: false (default, StyleX default)" do
    test "does not use @layer blocks" do
      # Default behavior - no layers, use :not(#\#) hack
      css = generate_css()

      # Should NOT have any @layer blocks
      refute css =~ "@layer "
    end

    test "uses :not(#\\#) hack for specificity bumping on conditional selectors" do
      css = generate_css()

      # Hover styles should use :not(#\#) hack for specificity
      # The hover_style has a :hover condition which needs bumping
      assert css =~ ":not(#\\#)"
    end

    test "rules from test modules are included in CSS" do
      css = generate_css()

      # Verify our test module's rules are in the generated CSS
      assert css =~ "color:red"
      assert css =~ "background-color:blue"
      assert css =~ "margin:10px"
    end
  end

  describe "use_css_layers: true (StyleX useLayers: true)" do
    setup do
      LiveStyle.Config.put(:use_css_layers, true)
      on_exit(fn -> LiveStyle.Config.reset(:use_css_layers) end)
      :ok
    end

    test "generates @layer declaration header" do
      css = generate_css()

      # Should have layer declaration header
      assert css =~ ~r/@layer priority\d+(, priority\d+)*;/
    end

    test "groups rules by priority level into @layer blocks" do
      css = generate_css()

      # Should have @layer priorityN blocks (with curly brace, not just semicolon)
      assert css =~ ~r/@layer priority\d+\{/
    end

    test "different priorities result in multiple layers" do
      css = generate_css()

      # Count unique priority layer numbers in the output
      layer_matches = Regex.scan(~r/@layer priority(\d+)\{/, css)
      layer_numbers = Enum.map(layer_matches, fn [_, n] -> String.to_integer(n) end)
      unique_layers = Enum.uniq(layer_numbers)

      # Should have multiple different priority layers (from different priority levels)
      assert length(unique_layers) > 1,
             "Expected multiple priority layers, got: #{inspect(unique_layers)}"
    end

    test "layer declaration lists all layers in ascending order" do
      css = generate_css()

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

    test "rules from test modules are included in CSS" do
      css = generate_css()

      # Verify our test module's rules are in the generated CSS
      assert css =~ "color:red"
      assert css =~ "background-color:blue"
      assert css =~ "margin:10px"
    end

    test "does not use :not(#\\#) hack when layers are enabled" do
      css = generate_css()

      # When using layers, specificity is handled by layer order, not :not(#\#) hack
      refute css =~ ":not(#\\#)"
    end
  end

  describe "priority layer grouping" do
    setup do
      LiveStyle.Config.put(:use_css_layers, true)
      on_exit(fn -> LiveStyle.Config.reset(:use_css_layers) end)
      :ok
    end

    test "shorthand properties appear in earlier layers than longhands" do
      css = generate_css()

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

  describe "config documentation" do
    test "use_css_layers? defaults to false (matching StyleX default)" do
      # Reset any overrides
      LiveStyle.Config.reset(:use_css_layers)

      assert LiveStyle.Config.use_css_layers?() == false
    end

    test "use_css_layers? can be set via config override" do
      LiveStyle.Config.put(:use_css_layers, true)
      assert LiveStyle.Config.use_css_layers?() == true

      LiveStyle.Config.put(:use_css_layers, false)
      assert LiveStyle.Config.use_css_layers?() == false
    end
  end
end
