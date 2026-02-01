defmodule LiveStyle.AtRulesTest do
  @moduledoc """
  Tests for at-rules: @media, @supports, @container, @starting-style.
  """
  use LiveStyle.TestCase

  defmodule MediaQueryModule do
    use LiveStyle

    class(:responsive_font,
      font_size: [
        default: "16px",
        "@media (max-width: 640px)": "14px",
        "@media (min-width: 1024px)": "18px"
      ]
    )

    class(:dark_mode,
      color: [
        default: "black",
        "@media (prefers-color-scheme: dark)": "white"
      ]
    )

    class(:reduced_motion,
      animation_duration: [
        default: "300ms",
        "@media (prefers-reduced-motion: reduce)": "0ms"
      ]
    )

    class(:print_style,
      background: [
        default: "gray",
        "@media print": "none"
      ]
    )
  end

  defmodule SupportsModule do
    use LiveStyle

    class(:grid_support,
      display: [
        default: "flex",
        "@supports (display: grid)": "grid"
      ]
    )

    class(:gap_support,
      margin: [
        default: "8px",
        "@supports (gap: 1px)": "0"
      ],
      gap: [
        "@supports (gap: 1px)": "8px"
      ]
    )
  end

  defmodule ContainerModule do
    use LiveStyle

    class(:container_responsive,
      padding: [
        default: "8px",
        "@container (min-width: 400px)": "16px",
        "@container (min-width: 800px)": "32px"
      ]
    )

    class(:named_container,
      font_size: [
        default: "14px",
        "@container sidebar (min-width: 300px)": "16px"
      ]
    )
  end

  defmodule StartingStyleModule do
    use LiveStyle

    class(:enter_animation,
      opacity: [
        default: "1",
        "@starting-style": "0"
      ],
      transform: [
        default: "none",
        "@starting-style": "translateY(-10px)"
      ]
    )
  end

  defmodule NestedAtRulesModule do
    use LiveStyle

    # @starting-style combined with @media should result in @media being outermost
    class(:responsive_enter,
      transform: [
        default: "none",
        "@starting-style@media (min-width: 640px)": "translateY(-0.5rem)"
      ]
    )

    # Multiple combinations to test priority ordering
    class(:complex_nesting,
      opacity: [
        default: "1",
        "@starting-style@supports (opacity: 0.5)@media (min-width: 768px)": "0"
      ]
    )
  end

  # Module to test @starting-style with responsive variants inside
  # The default should become an inverse media query to prevent "leaking"
  defmodule StartingStyleResponsiveModule do
    use LiveStyle

    # When @starting-style has responsive variants, default must become
    # an inverse media query. Otherwise, the unconditional default applies
    # at all viewports alongside the responsive variant.
    class(:toast_enter,
      transform: [
        default: "translateY(0)",
        "@starting-style": [
          default: "translateY(0.5rem)",
          "@media (min-width: 640px)": "translateY(-0.5rem)"
        ]
      ]
    )

    # Test with max-width instead of min-width
    class(:toast_enter_max,
      transform: [
        default: "translateY(0)",
        "@starting-style": [
          default: "translateY(0.5rem)",
          "@media (max-width: 640px)": "translateY(-0.5rem)"
        ]
      ]
    )
  end

  describe "@media queries" do
    test "responsive breakpoints generate media queries" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media (max-width: 640px)"
      assert css =~ "font-size:14px"
      assert css =~ "@media (min-width: 1024px)"
      assert css =~ "font-size:18px"
    end

    test "prefers-color-scheme generates media query" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media (prefers-color-scheme: dark)"
      assert css =~ "color:white"
    end

    test "prefers-reduced-motion generates media query" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media (prefers-reduced-motion: reduce)"
    end

    test "@media print generates print styles" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@media print"
    end

    test "media query class returns valid attrs" do
      attrs = LiveStyle.Compiler.get_css(MediaQueryModule, [:responsive_font])
      assert is_binary(attrs.class)
    end
  end

  describe "@supports queries" do
    test "generates @supports rules" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@supports (display: grid)"
      assert css =~ "display:grid"
    end

    test "fallback value for unsupported features" do
      css = LiveStyle.Compiler.generate_css()
      # Default value should exist outside @supports
      assert css =~ "display:flex"
    end
  end

  describe "@container queries" do
    test "generates @container rules" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@container (min-width: 400px)"
      assert css =~ "@container (min-width: 800px)"
    end

    test "named container generates correct syntax" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@container sidebar"
    end
  end

  describe "@starting-style" do
    test "generates @starting-style block" do
      css = LiveStyle.Compiler.generate_css()
      assert css =~ "@starting-style"
      assert css =~ "opacity:0"
      assert css =~ "translateY(-10px)"
    end

    test "@starting-style combined with @media has correct nesting order" do
      css = LiveStyle.Compiler.generate_css()
      # @media should be OUTSIDE (outermost), @starting-style should be INSIDE (innermost)
      # Expected: @media (min-width: 640px){@starting-style{...}}
      assert css =~ ~r/@media \(min-width: 640px\)\{@starting-style\{/
    end

    test "@starting-style with @supports and @media has correct nesting order" do
      css = LiveStyle.Compiler.generate_css()
      # Priority order (outermost to innermost): @supports > @media > @starting-style
      # Expected: @supports (opacity: 0.5){@media (min-width: 768px){@starting-style{...}}}
      assert css =~
               ~r/@supports \(opacity: 0\.5\)\{@media \(min-width: 768px\)\{@starting-style\{/
    end

    test "@starting-style with responsive variants generates exclusive media queries" do
      css = LiveStyle.Compiler.generate_css()

      # The default inside @starting-style should become @media (max-width: 639.99px)
      # to prevent it from "leaking" to desktop viewports
      assert css =~ ~r/@media \(max-width: 639\.99px\)\{@starting-style\{/

      # The responsive variant should be @media (min-width: 640px){@starting-style{...}}
      assert css =~ ~r/@media \(min-width: 640px\)\{@starting-style\{/

      # For toast_enter (0.5rem variant), both mobile and desktop should be media-wrapped
      # Mobile: @media (max-width: 639.99px){@starting-style{...translateY(.5rem)...}}
      assert css =~
               ~r/@media \(max-width: 639\.99px\)\{@starting-style\{[^}]*translateY\(\.5rem\)/

      # Desktop: @media (min-width: 640px){@starting-style{...translateY(-.5rem)...}}
      assert css =~ ~r/@media \(min-width: 640px\)\{@starting-style\{[^}]*translateY\(-\.5rem\)/
    end

    test "@starting-style with max-width responsive variant generates inverse min-width" do
      css = LiveStyle.Compiler.generate_css()

      # For max-width variants, default should become min-width + epsilon
      # @media (max-width: 640px) → default becomes @media (min-width: 640.01px)
      assert css =~ ~r/@media \(min-width: 640\.01px\)\{@starting-style\{/
    end
  end
end
