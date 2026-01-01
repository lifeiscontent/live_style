defmodule LiveStyle.Compiler.CSS.PriorityLayersEnabledTest do
  @moduledoc """
  Tests for CSS layers feature - layers enabled.

  When `use_css_layers: true` is set, LiveStyle groups CSS rules
  by priority level into separate `@layer priorityN` blocks, matching
  StyleX's `useLayers: true` behavior.
  """
  use LiveStyle.TestCase, use_css_layers: true

  # ============================================================================
  # Test Modules - Define styles with different priority levels
  # ============================================================================

  defmodule BasicStyles do
    use LiveStyle

    class(:color_style, color: "red")
    class(:background_style, background_color: "blue")
    class(:margin_style, margin: "10px")
    class(:margin_top_style, margin_top: "5px")
  end

  defmodule PseudoStyles do
    use LiveStyle

    class(:hover_style, color: [default: "blue", ":hover": "red"])
  end

  # ============================================================================
  # Tests - Layers enabled
  # ============================================================================

  describe "CSS layers output" do
    test "generates @layer declaration header" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ~r/@layer priority\d+(, priority\d+)*;/
    end

    test "groups rules by priority level into @layer blocks" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ ~r/@layer priority\d+\{/
    end

    test "different priorities result in multiple layers" do
      css = LiveStyle.Compiler.generate_css()

      layer_matches = Regex.scan(~r/@layer priority(\d+)\{/, css)
      layer_numbers = Enum.map(layer_matches, fn [_, n] -> String.to_integer(n) end)
      unique_layers = Enum.uniq(layer_numbers)

      assert length(unique_layers) > 1,
             "Expected multiple priority layers, got: #{inspect(unique_layers)}"
    end

    test "layer declaration lists all layers in ascending order" do
      css = LiveStyle.Compiler.generate_css()

      case Regex.run(~r/@layer [^;]+;/, css) do
        [declaration] ->
          layer_names = Regex.scan(~r/priority(\d+)/, declaration)
          layer_numbers = Enum.map(layer_names, fn [_, n] -> String.to_integer(n) end)

          assert layer_numbers == Enum.sort(layer_numbers),
                 "Layer declaration should be in ascending order, got: #{inspect(layer_numbers)}"

        nil ->
          flunk("No layer declaration found in CSS")
      end
    end

    test "rules from test modules are included in CSS" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "color:red"
      assert css =~ "background-color:blue"
      assert css =~ "margin:10px"
    end

    test "does not use :not(#\\#) hack when layers are enabled" do
      css = LiveStyle.Compiler.generate_css()
      refute css =~ ":not(#\\#)"
    end

    test "shorthand properties appear in earlier layers than longhands" do
      css = LiveStyle.Compiler.generate_css()

      margin_layer_match = Regex.run(~r/@layer priority(\d+)\{[^}]*margin:10px/s, css)
      margin_top_layer_match = Regex.run(~r/@layer priority(\d+)\{[^}]*margin-top:5px/s, css)

      if margin_layer_match && margin_top_layer_match do
        [_, margin_layer_str] = margin_layer_match
        [_, margin_top_layer_str] = margin_top_layer_match
        margin_layer = String.to_integer(margin_layer_str)
        margin_top_layer = String.to_integer(margin_top_layer_str)

        assert margin_layer < margin_top_layer,
               "margin (layer #{margin_layer}) should be in earlier layer than margin-top (layer #{margin_top_layer})"
      else
        margin_pos = :binary.match(css, "margin:10px") |> elem(0)
        margin_top_pos = :binary.match(css, "margin-top:5px") |> elem(0)

        assert margin_pos < margin_top_pos,
               "margin should appear before margin-top in CSS output"
      end
    end
  end
end
