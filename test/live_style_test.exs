defmodule LiveStyleTest do
  use ExUnit.Case, async: false

  setup do
    LiveStyle.clear()
    :ok
  end

  describe "style/2 macro" do
    test "defines a named style with CSS declarations" do
      defmodule TestBasicStyle do
        use LiveStyle

        style(:button, %{
          display: "flex",
          padding: "8px 16px"
        })
      end

      style = TestBasicStyle.__live_style__(:button)

      assert style[:display] == "flex"
      assert style[:padding] == "8px 16px"
    end

    test "generates atomic CSS classes" do
      defmodule TestAtomicClasses do
        use LiveStyle

        style(:test, %{
          display: "flex",
          color: "blue"
        })
      end

      css = LiveStyle.get_all_css()

      # Should have separate rules for each property
      assert css =~ "display: flex"
      assert css =~ "color: blue"
      # Class names should start with 'x'
      assert css =~ ~r/\.x[a-f0-9]+/
    end

    test "converts underscores to hyphens in property names" do
      defmodule TestPropertyConversion do
        use LiveStyle

        style(:test, %{
          background_color: "red",
          font_size: "16px",
          border_top_width: "1px"
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "background-color: red"
      assert css =~ "font-size: 16px"
      assert css =~ "border-top-width: 1px"
    end

    test "handles numeric values" do
      defmodule TestNumericValues do
        use LiveStyle

        style(:test, %{
          z_index: 100,
          opacity: 0.5,
          flex_grow: 1
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "z-index: 100"
      assert css =~ "opacity: 0.5"
      assert css =~ "flex-grow: 1"
    end

    test "generates deterministic class names for same property-value pairs" do
      defmodule TestDeterministic1 do
        use LiveStyle
        style(:a, %{display: "flex"})
      end

      defmodule TestDeterministic2 do
        use LiveStyle
        style(:b, %{display: "flex"})
      end

      css = LiveStyle.get_all_css()

      # Both should use the same class since property-value is identical
      # Count occurrences of "display: flex" - should be 1
      matches = Regex.scan(~r/display: flex/, css)
      assert length(matches) == 1
    end
  end

  describe "conditional values (StyleX pattern)" do
    test "handles pseudo-classes with condition-in-value syntax" do
      defmodule TestPseudoClass do
        use LiveStyle

        style(:link, %{
          color: %{
            default: "blue",
            ":hover": "darkblue",
            ":focus": "navy"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "color: blue"
      assert css =~ ":hover"
      assert css =~ "color: darkblue"
      assert css =~ ":focus"
      assert css =~ "color: navy"
    end

    test "handles media queries with condition-in-value syntax" do
      defmodule TestMediaQuery do
        use LiveStyle

        style(:responsive, %{
          padding: %{
            default: "8px",
            "@media (min-width: 768px)": "16px",
            "@media (min-width: 1024px)": "24px"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "padding: 8px"
      assert css =~ "@media (min-width: 768px)"
      assert css =~ "padding: 16px"
      assert css =~ "@media (min-width: 1024px)"
      assert css =~ "padding: 24px"
    end

    test "handles pseudo-elements" do
      defmodule TestPseudoElement do
        use LiveStyle

        style(:with_before, %{
          content: "''",
          "::before": %{
            content: "'*'",
            color: "red"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::before"
      assert css =~ "content: '*'"
    end
  end

  describe "var/1 macro" do
    test "generates CSS var() reference" do
      defmodule TestVar do
        use LiveStyle

        style(:test, %{
          color: var(:text_primary),
          padding: var(:space_4)
        })
      end

      style = TestVar.__live_style__(:test)

      assert style[:color] =~ ~r/var\(--v[a-f0-9]+\)/
      assert style[:padding] =~ ~r/var\(--v[a-f0-9]+\)/
    end

    test "generates deterministic var names based on namespace_name pattern" do
      defmodule TestVarDeterministic do
        use LiveStyle

        style(:a, %{color: var(:text_primary)})
        style(:b, %{background: var(:text_primary)})
      end

      style_a = TestVarDeterministic.__live_style__(:a)
      style_b = TestVarDeterministic.__live_style__(:b)

      # Same var name should produce same CSS variable
      assert style_a[:color] == style_b[:background]
    end
  end

  describe "first_that_works/1 macro" do
    test "generates fallback CSS values" do
      defmodule TestFallback do
        use LiveStyle

        style(:sticky_header, %{
          position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
        })
      end

      css = LiveStyle.get_all_css()

      # Should contain all fallback values
      assert css =~ "position: fixed"
      assert css =~ "position: -webkit-sticky"
      assert css =~ "position: sticky"
    end
  end

  describe "keyframes/2 macro" do
    test "defines a keyframes animation" do
      defmodule TestKeyframes do
        use LiveStyle

        keyframes(:spin, %{
          from: %{transform: "rotate(0deg)"},
          to: %{transform: "rotate(360deg)"}
        })

        style(:spinner, %{
          animation_name: :spin,
          animation_duration: "1s"
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "@keyframes"
      assert css =~ "from { transform: rotate(0deg); }"
      assert css =~ "to { transform: rotate(360deg); }"
    end

    test "keyframe name is used in animation-name" do
      defmodule TestKeyframeRef do
        use LiveStyle

        keyframes(:fade_in, %{
          from: %{opacity: "0"},
          to: %{opacity: "1"}
        })

        style(:fade, %{
          animation_name: :fade_in
        })
      end

      css = LiveStyle.get_all_css()

      # The generated keyframe name should be in both places
      assert Regex.match?(~r/@keyframes k[a-f0-9]+/, css)
      assert Regex.match?(~r/animation-name: k[a-f0-9]+/, css)
    end
  end

  describe "style/1 function (generated)" do
    test "returns class string for single style" do
      defmodule TestStyleFunc1 do
        use LiveStyle

        style(:base, %{display: "flex"})

        def get_class, do: style(:base)
      end

      class = TestStyleFunc1.get_class()
      assert is_binary(class)
      assert class =~ ~r/^x[a-f0-9]+$/
    end

    test "merges multiple styles with last-wins semantics" do
      defmodule TestStyleFunc2 do
        use LiveStyle

        style(:base, %{color: "red", padding: "8px"})
        style(:override, %{color: "blue"})

        def get_class, do: style([:base, :override])
      end

      class = TestStyleFunc2.get_class()
      classes = String.split(class, " ")

      # Should have 2 classes (padding from base, color from override)
      assert length(classes) == 2
    end

    test "filters out falsy values in style list" do
      defmodule TestStyleFunc3 do
        use LiveStyle

        style(:base, %{display: "flex"})
        style(:active, %{color: "blue"})

        def get_class(active?) do
          style([:base, active? && :active])
        end
      end

      with_active = TestStyleFunc3.get_class(true)
      without_active = TestStyleFunc3.get_class(false)

      assert String.split(with_active, " ") |> length() == 2
      assert String.split(without_active, " ") |> length() == 1
    end
  end

  describe "CSS output" do
    test "wraps rules in @layer live_style" do
      defmodule TestLayer do
        use LiveStyle
        style(:test, %{display: "flex"})
      end

      css = LiveStyle.get_all_css()
      assert css =~ "@layer live_style"
    end

    test "sorts rules by property priority" do
      defmodule TestPriority do
        use LiveStyle

        style(:test, %{
          color: "red",
          display: "flex",
          z_index: 10
        })
      end

      css = LiveStyle.get_all_css()

      display_pos = :binary.match(css, "display: flex") |> elem(0)
      color_pos = :binary.match(css, "color: red") |> elem(0)
      z_index_pos = :binary.match(css, "z-index: 10") |> elem(0)

      # display (100) < z-index (610) < color (800)
      assert display_pos < z_index_pos
      assert z_index_pos < color_pos
    end
  end

  describe "clear/0" do
    test "clears the manifest" do
      defmodule TestClear do
        use LiveStyle
        style(:test, %{display: "flex"})
      end

      css_before = LiveStyle.get_all_css()
      assert css_before =~ "display: flex"

      LiveStyle.clear()

      css_after = LiveStyle.get_all_css()
      refute css_after =~ "display: flex"
    end
  end
end
