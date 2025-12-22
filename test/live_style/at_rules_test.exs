defmodule LiveStyle.AtRulesTest do
  @moduledoc """
  Tests for CSS at-rules (@media, @supports, @container, @starting-style).

  These tests mirror StyleX's transform-stylex-create-test.js at-rule
  sections to ensure LiveStyle handles them the same way.
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Media Queries
  # ============================================================================

  defmodule MediaQueries do
    use LiveStyle

    css_class(:responsive,
      background_color: [
        default: "red",
        "@media (min-width: 1000px)": "blue",
        "@media (min-width: 2000px)": "purple"
      ]
    )

    css_class(:font_responsive,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": "2rem"
      ]
    )
  end

  defmodule MediaQueryNoDefault do
    use LiveStyle

    # StyleX supports conditional objects without a default branch:
    # maxWidth: { '@media (min-width: 800px)': '800px' }
    css_class(:root,
      max_width: ["@media (min-width: 800px)": "800px"]
    )
  end

  defmodule MediaQueryWithPseudo do
    use LiveStyle

    css_class(:hover_in_media,
      font_size: [
        default: "1rem",
        "@media (min-width: 800px)": [
          default: "2rem",
          ":hover": "2.2rem"
        ]
      ]
    )
  end

  defmodule ReducedMotionKeyframes do
    use LiveStyle

    css_keyframes(:shift,
      from: %{opacity: "0"},
      to: %{opacity: "1"}
    )

    css_class(:animated,
      animation_name: [
        default: css_keyframes(:shift),
        ":hover": css_keyframes(:shift),
        "@media (prefers-reduced-motion: reduce)": [
          default: "none",
          ":hover": "none"
        ]
      ]
    )
  end

  # ============================================================================
  # Supports Queries
  # ============================================================================

  defmodule SupportsQueries do
    use LiveStyle

    css_class(:hover_support,
      background_color: [
        default: "red",
        "@supports (hover: hover)": "blue",
        "@supports not (hover: hover)": "purple"
      ]
    )

    # @supports selector() syntax for feature detection
    css_class(:has_support,
      display: [
        default: "block",
        "@supports selector(:has(*))": "grid"
      ]
    )
  end

  # ============================================================================
  # Container Queries
  # ============================================================================

  defmodule ContainerQueries do
    use LiveStyle

    css_class(:container,
      font_size: [
        default: "1rem",
        "@container (min-width: 400px)": "2rem"
      ]
    )
  end

  # ============================================================================
  # Starting Style (Entry Animations)
  # ============================================================================

  defmodule StartingStyle do
    use LiveStyle

    # Basic @starting-style for entry animations
    css_class(:fade_in,
      opacity: %{
        :default => "1",
        "@starting-style" => "0"
      }
    )

    # @starting-style with transform
    css_class(:scale_in,
      transform: %{
        :default => "scale(1)",
        "@starting-style" => "scale(0.9)"
      }
    )

    # Multiple properties with @starting-style
    css_class(:slide_in,
      opacity: %{
        :default => "1",
        "@starting-style" => "0"
      },
      transform: %{
        :default => "translateY(0)",
        "@starting-style" => "translateY(-20px)"
      }
    )

    # @starting-style with nested pseudo-class (StyleX pattern)
    css_class(:hover_fade,
      opacity: %{
        :default => "1",
        "@starting-style" => %{
          :default => "0",
          ":hover" => "0.5"
        }
      }
    )
  end

  # ============================================================================
  # Triple-Nested Conditions
  # ============================================================================

  defmodule TripleNested do
    use LiveStyle

    # Triple nested: @media -> @supports -> :hover
    css_class(:triple_nested,
      color: [
        default: "black",
        "@media (min-width: 800px)": [
          default: "gray",
          "@supports (color: oklch(0 0 0))": [
            default: "oklch(0.5 0.2 250)",
            ":hover": "oklch(0.7 0.3 250)"
          ]
        ]
      ]
    )
  end

  describe "media queries" do
    test "supports media query values without default" do
      # StyleX supports conditional objects without a default branch:
      # https://github.com/stylexjs/stylex/blob/main/packages/%40stylexjs/stylex/README.md
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueryNoDefault, {:class, :root})
      classes = rule.atomic_classes["max-width"].classes

      assert Map.has_key?(classes, "@media (min-width: 800px)")
      refute Map.has_key?(classes, :default)
    end

    test "generates CSS with @media rules - exact StyleX output" do
      # StyleX test: 'media queries'
      # Input: backgroundColor: { default: 'red', '@media ...': 'blue', '@media ...': 'purple' }
      # Expected output (exact from StyleX):
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["xw6up8c", {ltr: "@media ...{.xw6up8c.xw6up8c{background-color:blue}}", rtl: null}, 3200]
      # ["x1ssfqz5", {ltr: "@media ...{.x1ssfqz5.x1ssfqz5{background-color:purple}}", rtl: null}, 3200]
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueries, {:class, :responsive})

      assert rule != nil
      classes = rule.atomic_classes["background-color"].classes

      # Default value - exact StyleX match
      default = classes[:default]
      assert default.class == "xrkmrrc"
      assert default.ltr == ".xrkmrrc{background-color:red}"
      assert default.priority == 3000

      # @media (min-width: 1000px) - transformed to add upper bound - exact StyleX match
      media_1000 = classes["@media (min-width: 1000px) and (max-width: 1999.99px)"]
      assert media_1000.class == "xw6up8c"

      assert media_1000.ltr ==
               "@media (min-width: 1000px) and (max-width: 1999.99px){.xw6up8c.xw6up8c{background-color:blue}}"

      assert media_1000.priority == 3200

      # @media (min-width: 2000px) - exact StyleX match
      media_2000 = classes["@media (min-width: 2000px)"]
      assert media_2000.class == "x1ssfqz5"

      assert media_2000.ltr ==
               "@media (min-width: 2000px){.x1ssfqz5.x1ssfqz5{background-color:purple}}"

      assert media_2000.priority == 3200
    end
  end

  describe "media query with pseudo-class" do
    test "generates CSS with pseudo-class inside media query - exact StyleX output" do
      # StyleX test: 'media query with pseudo-classes'
      # Input: fontSize: { default: '1rem', '@media (min-width: 800px)': { default: '2rem', ':hover': '2.2rem' } }
      # Expected output (exact from StyleX):
      # ["x1jchvi3", {ltr: ".x1jchvi3{font-size:1rem}", rtl: null}, 3000]
      # ["x1w3nbkt", {ltr: "@media (min-width: 800px){.x1w3nbkt.x1w3nbkt{font-size:2rem}}", rtl: null}, 3200]
      # ["xicay7j", {ltr: "@media (min-width: 800px){.xicay7j.xicay7j:hover{font-size:2.2rem}}", rtl: null}, 3330]
      rule =
        LiveStyle.get_metadata(
          LiveStyle.AtRulesTest.MediaQueryWithPseudo,
          {:class, :hover_in_media}
        )

      classes = rule.atomic_classes["font-size"].classes

      # Default: 1rem - exact StyleX match
      default = classes[:default]
      assert default.class == "x1jchvi3"
      assert default.ltr == ".x1jchvi3{font-size:1rem}"
      assert default.priority == 3000

      # @media (min-width: 800px) default: 2rem - exact StyleX match
      media_default = classes["@media (min-width: 800px)"]
      assert media_default.class == "x1w3nbkt"
      assert media_default.ltr == "@media (min-width: 800px){.x1w3nbkt.x1w3nbkt{font-size:2rem}}"
      assert media_default.priority == 3200

      # @media (min-width: 800px):hover: 2.2rem - exact StyleX match
      media_hover = classes["@media (min-width: 800px):hover"]
      assert media_hover.class == "xicay7j"

      assert media_hover.ltr ==
               "@media (min-width: 800px){.xicay7j.xicay7j:hover{font-size:2.2rem}}"

      assert media_hover.priority == 3330
    end

    test "supports reduced-motion overrides inside nested media query objects" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.ReducedMotionKeyframes, {:class, :animated})

      keyframes =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.ReducedMotionKeyframes, {:keyframes, :shift})

      classes = rule.atomic_classes["animation-name"].classes

      # Default: keyframes reference
      default = classes[:default]
      assert default.ltr =~ ~r/^\.x[a-z0-9]+\{animation-name:#{keyframes.css_name}\}$/
      assert default.priority == 3000

      # :hover: keyframes reference
      hover = classes[":hover"]
      assert hover.ltr =~ ~r/^\.x[a-z0-9]+:hover\{animation-name:#{keyframes.css_name}\}$/
      assert hover.priority == 3130

      # Reduced motion: override both default and hover with "none"
      media_default = classes["@media (prefers-reduced-motion: reduce)"]
      assert media_default.ltr =~ "@media (prefers-reduced-motion: reduce)"
      assert media_default.ltr =~ "{animation-name:none}"
      assert media_default.priority == 3200

      media_hover = classes["@media (prefers-reduced-motion: reduce):hover"]
      assert media_hover.ltr =~ "@media (prefers-reduced-motion: reduce)"
      assert media_hover.ltr =~ ":hover{animation-name:none}"
      assert media_hover.priority == 3330
    end
  end

  describe "supports queries" do
    test "generates CSS with @supports rules - exact StyleX output" do
      # StyleX test: 'supports queries'
      # Input: backgroundColor: { default:'red', '@supports ...': 'blue', '@supports not ...': 'purple' }
      # Expected output (exact from StyleX):
      # ["xrkmrrc", {ltr: ".xrkmrrc{background-color:red}", rtl: null}, 3000]
      # ["x6m3b6q", {ltr: "@supports ...{.x6m3b6q.x6m3b6q{background-color:blue}}", rtl: null}, 3030]
      # ["x6um648", {ltr: "@supports not ...{.x6um648.x6um648{background-color:purple}}", rtl: null}, 3030]
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.SupportsQueries, {:class, :hover_support})

      classes = rule.atomic_classes["background-color"].classes

      # Default value - exact StyleX match
      default = classes[:default]
      assert default.class == "xrkmrrc"
      assert default.ltr == ".xrkmrrc{background-color:red}"
      assert default.priority == 3000

      # @supports (hover: hover) - exact StyleX match
      supports_hover = classes["@supports (hover: hover)"]
      assert supports_hover.class == "x6m3b6q"

      assert supports_hover.ltr ==
               "@supports (hover: hover){.x6m3b6q.x6m3b6q{background-color:blue}}"

      assert supports_hover.priority == 3030

      # @supports not (hover: hover) - exact StyleX match
      supports_not_hover = classes["@supports not (hover: hover)"]
      assert supports_not_hover.class == "x6um648"

      assert supports_not_hover.ltr ==
               "@supports not (hover: hover){.x6um648.x6um648{background-color:purple}}"

      assert supports_not_hover.priority == 3030
    end

    test "generates CSS with @supports selector() syntax" do
      # @supports selector(:has(*)) - feature detection for :has() selector support
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.SupportsQueries, {:class, :has_support})

      classes = rule.atomic_classes["display"].classes

      # Default value
      default = classes[:default]
      assert default.ltr == ".#{default.class}{display:block}"
      assert default.priority == 3000

      # @supports selector(:has(*))
      supports_selector = classes["@supports selector(:has(*))"]
      assert supports_selector.ltr =~ "@supports selector(:has(*))"
      assert supports_selector.ltr =~ "display:grid"
      assert supports_selector.priority == 3030
    end
  end

  describe "container queries" do
    test "generates CSS with @container rules and correct priorities" do
      # @container priority should be 3000 + 300 = 3300
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.ContainerQueries, {:class, :container})

      classes = rule.atomic_classes["font-size"].classes

      # Default
      default = classes[:default]
      assert default.priority == 3000

      # @container (min-width: 400px)
      container = classes["@container (min-width: 400px)"]
      assert container.ltr =~ "@container (min-width: 400px)"
      assert container.ltr =~ "font-size:2rem"
      assert container.priority == 3300
    end

    test "@container rules have doubled class selector" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.ContainerQueries, {:class, :container})

      container = rule.atomic_classes["font-size"].classes["@container (min-width: 400px)"]

      # Look for pattern like .x123.x123 inside @container
      assert container.ltr =~ ~r/@container[^{]+\{\.[a-z0-9]+\.[a-z0-9]+\{/
    end
  end

  describe "at-rule priority ordering" do
    # StyleX priority order:
    # @supports: +30 (3030)
    # @media: +200 (3200)
    # @container: +300 (3300)
    # Higher numbers win (applied later)

    test "at-rules have correct relative priority" do
      # @supports < @media < @container
      assert LiveStyle.Priority.get_at_rule_priority("@supports (x)") == 30
      assert LiveStyle.Priority.get_at_rule_priority("@media (x)") == 200
      assert LiveStyle.Priority.get_at_rule_priority("@container (x)") == 300

      supports_priority = LiveStyle.Priority.calculate("color", nil, "@supports (x)")
      media_priority = LiveStyle.Priority.calculate("color", nil, "@media (x)")
      container_priority = LiveStyle.Priority.calculate("color", nil, "@container (x)")

      assert supports_priority == 3030
      assert media_priority == 3200
      assert container_priority == 3300

      assert supports_priority < media_priority
      assert media_priority < container_priority
    end
  end

  # ============================================================================
  # Additional At-Rule Scenarios
  # ============================================================================

  defmodule NestedAtRules do
    use LiveStyle

    # Nested at-rules: @supports wrapping @media
    # StyleX test: "tokens object with nested @-rules"
    css_vars(:colors,
      color: %{
        default: "blue",
        "@media (prefers-color-scheme: dark)": %{
          default: "lightblue",
          "@supports (color: oklab(0 0 0))": "oklab(0.7 -0.3 -0.4)"
        }
      }
    )
  end

  defmodule MultipleMediaQueries do
    use LiveStyle

    # Multiple different media queries on same property
    css_class(:responsive,
      padding: [
        default: "8px",
        "@media (min-width: 640px)": "16px",
        "@media (min-width: 768px)": "24px",
        "@media (min-width: 1024px)": "32px",
        "@media (min-width: 1280px)": "48px"
      ]
    )
  end

  defmodule MediaQueryTypes do
    use LiveStyle

    # Different types of media queries
    css_class(:print,
      display: [
        default: "block",
        "@media print": "none"
      ]
    )

    css_class(:dark_mode,
      background_color: [
        default: "white",
        "@media (prefers-color-scheme: dark)": "black"
      ]
    )

    css_class(:reduced_motion,
      transition: [
        default: "all 0.3s ease",
        "@media (prefers-reduced-motion: reduce)": "none"
      ]
    )

    css_class(:max_width,
      font_size: [
        default: "16px",
        "@media (max-width: 640px)": "14px"
      ]
    )
  end

  defmodule SupportsQueryTypes do
    use LiveStyle

    # Different types of @supports queries
    css_class(:grid_support,
      display: [
        default: "flex",
        "@supports (display: grid)": "grid"
      ]
    )

    css_class(:gap_support,
      margin: [
        default: "10px",
        "@supports (gap: 10px)": "0"
      ]
    )

    css_class(:aspect_ratio_support,
      padding_bottom: [
        default: "56.25%",
        "@supports (aspect-ratio: 16 / 9)": "0"
      ]
    )
  end

  defmodule ContainerQueryTypes do
    use LiveStyle

    # Different container query conditions
    css_class(:inline_size,
      font_size: [
        default: "1rem",
        "@container (inline-size > 300px)": "1.25rem"
      ]
    )

    css_class(:named_container,
      padding: [
        default: "8px",
        "@container sidebar (min-width: 200px)": "16px"
      ]
    )
  end

  describe "nested at-rules" do
    test "nested @supports inside @media generates correct CSS" do
      # StyleX output for nested @-rules:
      # @supports wraps @media (innermost at-rule becomes outermost wrapper)
      css = generate_css()

      color_var =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.NestedAtRules, {:var, :colors, :color})

      var_name = color_var.css_name

      # Should have default value in :root
      assert css =~ ~r/:root\{[^}]*#{Regex.escape(var_name)}:blue;/

      # Should have @media wrapped value for dark mode default
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*#{Regex.escape(var_name)}:lightblue;/

      # Should have @supports wrapping @media for the nested value
      # StyleX nests as: @supports{@media{:root{...}}}
      assert css =~
               ~r/@supports \(color: oklab\(0 0 0\)\)\{@media \(prefers-color-scheme: dark\)\{:root\{[^}]*#{Regex.escape(var_name)}:oklab/
    end
  end

  describe "triple-nested conditions" do
    test "triple nesting generates properly wrapped at-rules with pseudo-class" do
      # Triple nested: @media -> @supports -> :hover
      # StyleX nests at-rules: @media{@supports{.selector:hover{...}}}
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.TripleNested, {:class, :triple_nested})

      classes = rule.atomic_classes["color"].classes

      # Default value
      default = classes[:default]
      assert default.ltr == ".#{default.class}{color:black}"
      assert default.priority == 3000

      # @media (min-width: 800px)
      media_only = classes["@media (min-width: 800px)"]

      assert media_only.ltr ==
               "@media (min-width: 800px){.#{media_only.class}.#{media_only.class}{color:gray}}"

      # @media (min-width: 800px)@supports (color: oklch(0 0 0))
      # StyleX sorts at-rules alphabetically, then wraps left-to-right
      # @media < @supports alphabetically, so @supports ends up as outer wrapper
      # Should be nested: @supports{@media{...}}
      media_supports =
        classes["@media (min-width: 800px)@supports (color: oklch(0 0 0))"]

      assert media_supports.ltr =~
               "@supports (color: oklch(0 0 0)){@media (min-width: 800px){"

      assert media_supports.ltr =~ "color:oklch("
      assert media_supports.at_rule == "@media (min-width: 800px)@supports (color: oklch(0 0 0))"

      # @media (min-width: 800px)@supports (color: oklch(0 0 0)):hover
      # Same alphabetical sorting: @supports{@media{.selector:hover{...}}}
      media_supports_hover =
        classes["@media (min-width: 800px)@supports (color: oklch(0 0 0)):hover"]

      assert media_supports_hover.ltr =~
               "@supports (color: oklch(0 0 0)){@media (min-width: 800px){"

      assert media_supports_hover.ltr =~ ":hover{color:oklch("
      assert media_supports_hover.selector_suffix == ":hover"

      assert media_supports_hover.at_rule ==
               "@media (min-width: 800px)@supports (color: oklch(0 0 0))"
    end
  end

  describe "multiple media queries" do
    test "generates bounded media queries for consecutive min-width values" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.MultipleMediaQueries, {:class, :responsive})

      classes = rule.atomic_classes["padding"].classes

      # Default: 8px
      assert classes[:default].ltr =~ "padding:8px"

      # First media query should be bounded (640px - 767.99px)
      media_640 = classes["@media (min-width: 640px) and (max-width: 767.99px)"]
      assert media_640 != nil
      assert media_640.ltr =~ "padding:16px"

      # Second media query should be bounded (768px - 1023.99px)
      media_768 = classes["@media (min-width: 768px) and (max-width: 1023.99px)"]
      assert media_768 != nil
      assert media_768.ltr =~ "padding:24px"

      # Third media query should be bounded (1024px - 1279.99px)
      media_1024 = classes["@media (min-width: 1024px) and (max-width: 1279.99px)"]
      assert media_1024 != nil
      assert media_1024.ltr =~ "padding:32px"

      # Last media query should NOT be bounded (1280px+)
      media_1280 = classes["@media (min-width: 1280px)"]
      assert media_1280 != nil
      assert media_1280.ltr =~ "padding:48px"
      refute media_1280.ltr =~ "max-width"
    end
  end

  describe "media query types" do
    test "@media print generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueryTypes, {:class, :print})
      classes = rule.atomic_classes["display"].classes

      print_class = classes["@media print"]
      assert print_class != nil
      assert print_class.ltr =~ "@media print"
      assert print_class.ltr =~ "display:none"
    end

    test "@media (prefers-color-scheme: dark) generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueryTypes, {:class, :dark_mode})
      classes = rule.atomic_classes["background-color"].classes

      dark_class = classes["@media (prefers-color-scheme: dark)"]
      assert dark_class != nil
      assert dark_class.ltr =~ "@media (prefers-color-scheme: dark)"
      assert dark_class.ltr =~ "background-color:black"
    end

    test "@media (prefers-reduced-motion: reduce) generates correct CSS" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueryTypes, {:class, :reduced_motion})

      classes = rule.atomic_classes["transition"].classes

      motion_class = classes["@media (prefers-reduced-motion: reduce)"]
      assert motion_class != nil
      assert motion_class.ltr =~ "@media (prefers-reduced-motion: reduce)"
      assert motion_class.ltr =~ "transition:none"
    end

    test "@media (max-width: ...) generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.MediaQueryTypes, {:class, :max_width})
      classes = rule.atomic_classes["font-size"].classes

      max_width_class = classes["@media (max-width: 640px)"]
      assert max_width_class != nil
      assert max_width_class.ltr =~ "@media (max-width: 640px)"
      assert max_width_class.ltr =~ "font-size:14px"
    end
  end

  describe "supports query types" do
    test "@supports (display: grid) generates correct CSS" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.SupportsQueryTypes, {:class, :grid_support})

      classes = rule.atomic_classes["display"].classes

      grid_class = classes["@supports (display: grid)"]
      assert grid_class != nil
      assert grid_class.ltr =~ "@supports (display: grid)"
      assert grid_class.ltr =~ "display:grid"
    end

    test "@supports (gap: ...) generates correct CSS" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.SupportsQueryTypes, {:class, :gap_support})

      classes = rule.atomic_classes["margin"].classes

      gap_class = classes["@supports (gap: 10px)"]
      assert gap_class != nil
      assert gap_class.ltr =~ "@supports (gap: 10px)"
      assert gap_class.ltr =~ "margin:0"
    end

    test "@supports (aspect-ratio: ...) generates correct CSS" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.AtRulesTest.SupportsQueryTypes,
          {:class, :aspect_ratio_support}
        )

      classes = rule.atomic_classes["padding-bottom"].classes

      aspect_class = classes["@supports (aspect-ratio: 16 / 9)"]
      assert aspect_class != nil
      assert aspect_class.ltr =~ "@supports (aspect-ratio: 16 / 9)"
      assert aspect_class.ltr =~ "padding-bottom:0"
    end
  end

  describe "container query types" do
    test "@container (inline-size > ...) generates correct CSS" do
      rule =
        LiveStyle.get_metadata(LiveStyle.AtRulesTest.ContainerQueryTypes, {:class, :inline_size})

      classes = rule.atomic_classes["font-size"].classes

      inline_class = classes["@container (inline-size > 300px)"]
      assert inline_class != nil
      assert inline_class.ltr =~ "@container (inline-size > 300px)"
      assert inline_class.ltr =~ "font-size:1.25rem"
    end

    test "@container with named container generates correct CSS" do
      rule =
        LiveStyle.get_metadata(
          LiveStyle.AtRulesTest.ContainerQueryTypes,
          {:class, :named_container}
        )

      classes = rule.atomic_classes["padding"].classes

      named_class = classes["@container sidebar (min-width: 200px)"]
      assert named_class != nil
      assert named_class.ltr =~ "@container sidebar (min-width: 200px)"
      assert named_class.ltr =~ "padding:16px"
    end
  end

  # ============================================================================
  # @starting-style Tests
  # ============================================================================

  describe "@starting-style" do
    test "basic @starting-style generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.StartingStyle, {:class, :fade_in})
      classes = rule.atomic_classes["opacity"].classes

      # Default value
      default = classes[:default]
      assert default.ltr == ".#{default.class}{opacity:1}"
      # opacity is a longhand-logical property (priority 3000)
      assert default.priority == 3000

      # @starting-style value
      starting = classes["@starting-style"]
      assert starting != nil
      assert starting.ltr =~ "@starting-style"
      assert starting.ltr =~ "opacity:0"
      # Priority should be property_priority (3000) + at_rule_priority (20) = 3020
      assert starting.priority == 3020
    end

    test "@starting-style with transform generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.StartingStyle, {:class, :scale_in})
      classes = rule.atomic_classes["transform"].classes

      starting = classes["@starting-style"]
      assert starting != nil
      assert starting.ltr =~ "@starting-style"
      assert starting.ltr =~ "transform:scale(.9)"
    end

    test "multiple properties with @starting-style" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.StartingStyle, {:class, :slide_in})

      # Opacity
      opacity_classes = rule.atomic_classes["opacity"].classes
      opacity_starting = opacity_classes["@starting-style"]
      assert opacity_starting.ltr =~ "@starting-style"
      assert opacity_starting.ltr =~ "opacity:0"

      # Transform
      transform_classes = rule.atomic_classes["transform"].classes
      transform_starting = transform_classes["@starting-style"]
      assert transform_starting.ltr =~ "@starting-style"
      assert transform_starting.ltr =~ "transform:translateY(-20px)"
    end

    test "@starting-style has correct priority relative to other at-rules" do
      # @starting-style: 20 (should be lower than @supports)
      # @supports: 30
      # @media: 200
      # @container: 300
      assert LiveStyle.Priority.get_at_rule_priority("@starting-style") == 20
      assert LiveStyle.Priority.get_at_rule_priority("@supports (x)") == 30
      assert LiveStyle.Priority.get_at_rule_priority("@media (x)") == 200
      assert LiveStyle.Priority.get_at_rule_priority("@container (x)") == 300

      # @starting-style should have lowest at-rule priority
      starting_priority = LiveStyle.Priority.get_at_rule_priority("@starting-style")
      supports_priority = LiveStyle.Priority.get_at_rule_priority("@supports (x)")
      assert starting_priority < supports_priority
    end

    test "@starting-style rules have doubled class selector" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.StartingStyle, {:class, :fade_in})
      starting = rule.atomic_classes["opacity"].classes["@starting-style"]

      # Should have doubled selector like .x123.x123 inside @starting-style
      assert starting.ltr =~ ~r/@starting-style\{\.[a-z0-9]+\.[a-z0-9]+\{/
    end

    test "@starting-style with nested pseudo-class generates correct CSS" do
      rule = LiveStyle.get_metadata(LiveStyle.AtRulesTest.StartingStyle, {:class, :hover_fade})
      classes = rule.atomic_classes["opacity"].classes

      # @starting-style default
      starting_default = classes["@starting-style"]
      assert starting_default != nil
      assert starting_default.ltr =~ "@starting-style"
      assert starting_default.ltr =~ "opacity:0"

      # @starting-style:hover - nested pseudo inside at-rule
      starting_hover = classes["@starting-style:hover"]
      assert starting_hover != nil
      assert starting_hover.ltr =~ "@starting-style"
      assert starting_hover.ltr =~ ":hover"
      assert starting_hover.ltr =~ "opacity:.5"
    end
  end
end
