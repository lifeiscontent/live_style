defmodule LiveStyle.KeywordSyntaxTest do
  @moduledoc """
  Tests for keyword list syntax support across all LiveStyle macros.

  LiveStyle accepts both map and keyword list syntax for all declarations:

      # Map syntax (original)
      style :button, %{display: "flex", padding: "8px"}

      # Keyword list syntax (more idiomatic Elixir)
      style :button, display: "flex", padding: "8px"
  """
  use ExUnit.Case, async: false

  # Helper to compute the expected class name
  defp class_name(property, value, selector_suffix \\ nil, at_rule \\ nil) do
    input = "#{property}:#{value}:#{selector_suffix || ""}:#{at_rule || ""}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "x#{hash}"
  end

  # Helper to compute the expected keyframe name
  defp keyframe_name(module, name) do
    input = "#{module}:#{name}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "k#{hash}"
  end

  setup do
    LiveStyle.clear()
    :ok
  end

  # ===========================================================================
  # style/2 keyword list syntax
  # ===========================================================================

  describe "style/2 with keyword list" do
    test "accepts keyword list instead of map" do
      defmodule KeywordStyleBasic do
        use LiveStyle

        style(:button,
          display: "flex",
          color: "blue",
          padding: "8px 16px"
        )
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("display", "flex")} { display: flex; }"
      assert css =~ ".#{class_name("color", "blue")} { color: blue; }"
      assert css =~ ".#{class_name("padding", "8px 16px")} { padding: 8px 16px; }"
    end

    test "accepts nested keyword lists for conditions" do
      defmodule KeywordStyleConditions do
        use LiveStyle

        style(:link,
          color: [
            default: "blue",
            ":hover": "darkblue",
            ":active": "navy"
          ]
        )
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("color", "blue")} { color: blue; }"
      assert css =~ ".#{class_name("color", "darkblue", ":hover")}:hover { color: darkblue; }"
      assert css =~ ".#{class_name("color", "navy", ":active")}:active { color: navy; }"
    end

    test "accepts nested keyword lists for pseudo-elements" do
      defmodule KeywordPseudoElements do
        use LiveStyle

        style(:decorated,
          position: "relative",
          "::before": [
            content: "''",
            position: "absolute"
          ]
        )
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("position", "relative")} { position: relative; }"
      assert css =~ ".#{class_name("content", "''", "::before")}::before { content: ''; }"
    end

    test "deeply nested keyword list conditions" do
      defmodule DeepKeywordNesting do
        use LiveStyle

        style(:complex,
          opacity: [
            default: "1",
            ":hover": [
              default: "0.9",
              ":focus": "0.8"
            ]
          ]
        )
      end

      css = LiveStyle.get_all_css()
      assert css =~ "opacity: 1"
      assert css =~ ".#{class_name("opacity", "0.9", ":hover")}:hover { opacity: 0.9; }"

      assert css =~
               ".#{class_name("opacity", "0.8", ":hover:focus")}:hover:focus { opacity: 0.8; }"
    end

    test "mixing keyword list and map syntax in same module" do
      defmodule MixedSyntax do
        use LiveStyle

        # Keyword list syntax
        style(:base,
          display: "flex",
          padding: "8px"
        )

        # Map syntax
        style(:primary, %{
          background_color: "blue",
          color: "white"
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ "display: flex"
      assert css =~ "padding: 8px"
      assert css =~ "background-color: blue"
      assert css =~ "color: white"
    end
  end

  # ===========================================================================
  # keyframes/2 keyword list syntax
  # ===========================================================================

  describe "keyframes/2 with keyword list" do
    test "accepts keyword list syntax" do
      defmodule KeywordKeyframes do
        use LiveStyle

        keyframes(:spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]
        )

        style(:spinner, animation_name: :spin)
      end

      css = LiveStyle.get_all_css()
      kf_name = keyframe_name(KeywordKeyframes, :spin)
      assert css =~ "@keyframes #{kf_name}"
      assert css =~ "from { transform: rotate(0deg); }"
      assert css =~ "to { transform: rotate(360deg); }"
    end
  end

  # ===========================================================================
  # defvars/2 keyword list syntax
  # ===========================================================================

  describe "defvars/2 with keyword list" do
    test "accepts keyword list" do
      defmodule KeywordDefvars do
        use LiveStyle.Tokens

        defvars(:color,
          primary: "#1e68fa",
          secondary: "#6b7280"
        )
      end

      css = LiveStyle.get_all_css()

      assert css =~ ":root {"
      assert css =~ "#1e68fa"
      assert css =~ "#6b7280"
    end
  end

  # ===========================================================================
  # defconsts/2 keyword list syntax
  # ===========================================================================

  describe "defconsts/2 with keyword list" do
    test "accepts keyword list" do
      defmodule KeywordDefconsts do
        use LiveStyle.Tokens

        defconsts(:breakpoints,
          sm: "@media (max-width: 640px)",
          lg: "@media (min-width: 1024px)"
        )
      end

      assert KeywordDefconsts.breakpoints_sm() == "@media (max-width: 640px)"
      assert KeywordDefconsts.breakpoints_lg() == "@media (min-width: 1024px)"
    end
  end

  # ===========================================================================
  # defkeyframes/2 keyword list syntax
  # ===========================================================================

  describe "defkeyframes/2 with keyword list" do
    test "accepts keyword list with nested keyword lists" do
      defmodule KeywordDefkeyframes do
        use LiveStyle.Tokens

        defkeyframes(:fade_in,
          from: [opacity: "0"],
          to: [opacity: "1"]
        )
      end

      css = LiveStyle.get_all_css()

      keyframe_name = KeywordDefkeyframes.fade_in()
      assert css =~ "@keyframes #{keyframe_name}"
      assert css =~ "from { opacity: 0; }"
      assert css =~ "to { opacity: 1; }"
    end
  end

  # ===========================================================================
  # create_theme/3 keyword list syntax
  # ===========================================================================

  describe "create_theme/3 with keyword list" do
    test "accepts keyword list" do
      defmodule KeywordThemeBase do
        use LiveStyle.Tokens

        defvars(:fill,
          background: "#ffffff",
          surface: "#f5f5f5"
        )

        create_theme(:dark, :fill,
          background: "#1a1a1a",
          surface: "#2d2d2d"
        )
      end

      theme_class = KeywordThemeBase.dark()
      assert is_binary(theme_class)

      css = LiveStyle.get_all_css()
      assert css =~ ".#{theme_class}"
      assert css =~ "#1a1a1a"
    end
  end

  # ===========================================================================
  # view_transition/2 keyword list syntax
  # ===========================================================================

  describe "view_transition/2 with keyword list" do
    test "accepts keyword list" do
      defmodule TestKeywordViewTransition do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("kw-*",
          old: [
            animation: "250ms ease-out both fade_out"
          ],
          new: [
            animation: "250ms ease-out both fade_in"
          ]
        )
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(kw-*)"
      assert css =~ "::view-transition-new(kw-*)"
      assert css =~ "animation: 250ms ease-out both fade_out;"
      assert css =~ "animation: 250ms ease-out both fade_in;"
    end

    test "accepts nested keyword lists for conditionals" do
      defmodule TestKeywordConditional do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("kw-cond-*",
          old: [
            animation: [
              default: "250ms ease-out both fade_out",
              "@media (prefers-reduced-motion: reduce)": "none"
            ]
          ]
        )
      end

      css = LiveStyle.get_all_css()

      assert css =~ "animation: 250ms ease-out both fade_out;"
      assert css =~ "@media (prefers-reduced-motion: reduce)"
      assert css =~ "animation: none;"
    end

    test "with defkeyframes using keyword list" do
      defmodule TestKeywordKeyframeRef do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        defkeyframes(:kw_fade_out,
          from: [opacity: "1"],
          to: [opacity: "0"]
        )

        view_transition("kw-anim-*",
          old: [
            animation_name: :kw_fade_out,
            animation_duration: "200ms"
          ]
        )
      end

      css = LiveStyle.get_all_css()

      # Should contain hashed keyframe name
      assert css =~ ~r/animation-name: k[a-f0-9]+;/
      assert css =~ "animation-duration: 200ms;"
    end

    test "handles :only-child variants with keyword list" do
      defmodule TestKeywordOnlyChild do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("kw-child-*",
          old_only_child: [
            animation: "300ms ease-out both scale_out"
          ],
          new_only_child: [
            animation: "300ms ease-out both scale_in"
          ]
        )
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(kw-child-*):only-child"
      assert css =~ "::view-transition-new(kw-child-*):only-child"
    end
  end

  # ===========================================================================
  # Mixed syntax in same module
  # ===========================================================================

  describe "mixed syntax" do
    test "mixing keyword and map syntax in tokens module" do
      defmodule MixedTokensSyntax do
        use LiveStyle.Tokens

        # Keyword syntax
        defvars(:color,
          white: "#ffffff",
          black: "#000000"
        )

        # Map syntax
        defvars(:space, %{
          sm: "0.5rem",
          md: "1rem"
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "#ffffff"
      assert css =~ "#000000"
      assert css =~ "0.5rem"
      assert css =~ "1rem"
    end

    test "mixing keyword and map syntax in view transitions" do
      defmodule TestMixedViewTransition do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        # Keyword syntax
        view_transition("mixed-kw-*",
          old: [animation: "200ms fade_out"]
        )

        # Map syntax
        view_transition("mixed-map-*", %{
          new: %{animation: "200ms fade_in"}
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(mixed-kw-*)"
      assert css =~ "::view-transition-new(mixed-map-*)"
    end
  end
end
