defmodule LiveStyleTest do
  use ExUnit.Case, async: false

  # Helper to compute the expected class name (mirrors LiveStyle.generate_class_name/4)
  defp class_name(property, value, selector_suffix \\ nil, at_rule \\ nil) do
    input = "#{property}:#{value}:#{selector_suffix || ""}:#{at_rule || ""}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "x#{hash}"
  end

  # Helper to compute the expected keyframe name (uses module:name)
  defp keyframe_name(module, name) do
    input = "#{module}:#{name}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "k#{hash}"
  end

  # Helper to compute the expected CSS variable name
  defp var_name(atom_name) do
    name_str = Atom.to_string(atom_name)
    input = name_str |> String.replace("_", ":")

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "--v#{hash}"
  end

  setup do
    LiveStyle.clear()
    :ok
  end

  # ===========================================================================
  # Basic style/2 macro
  # ===========================================================================

  describe "style/2 macro" do
    test "generates atomic CSS for simple properties" do
      defmodule BasicStyle do
        use LiveStyle

        style(:button, %{
          display: "flex",
          color: "blue"
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("display", "flex")} { display: flex; }"
      assert css =~ ".#{class_name("color", "blue")} { color: blue; }"
    end

    test "converts underscores to hyphens in property names" do
      defmodule UnderscoreProps do
        use LiveStyle

        style(:test, %{
          background_color: "red",
          font_size: "16px"
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "red")} { background-color: red; }"
      assert css =~ ".#{class_name("font-size", "16px")} { font-size: 16px; }"
    end

    test "handles numeric values" do
      defmodule NumericValues do
        use LiveStyle

        style(:test, %{
          z_index: 100,
          opacity: 0.5
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("z-index", "100")} { z-index: 100; }"
      assert css =~ ".#{class_name("opacity", "0.5")} { opacity: 0.5; }"
    end

    test "deduplicates identical property-value pairs" do
      defmodule Dedupe1 do
        use LiveStyle
        style(:a, %{display: "flex"})
      end

      defmodule Dedupe2 do
        use LiveStyle
        style(:b, %{display: "flex"})
      end

      css = LiveStyle.get_all_css()
      # Should only have one rule for display: flex
      display_class = class_name("display", "flex")
      assert length(Regex.scan(~r/\.#{display_class}/, css)) == 1
    end
  end

  # ===========================================================================
  # Pseudo-classes as conditions in property values
  # ===========================================================================

  describe "pseudo-classes" do
    test ":hover condition" do
      defmodule HoverTest do
        use LiveStyle

        style(:link, %{
          color: %{
            default: "blue",
            ":hover": "darkblue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("color", "blue")} { color: blue; }"
      assert css =~ ".#{class_name("color", "darkblue", ":hover")}:hover { color: darkblue; }"
    end

    test ":focus condition" do
      defmodule FocusTest do
        use LiveStyle

        style(:input, %{
          outline: %{
            default: "none",
            ":focus": "2px solid blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("outline", "none")} { outline: none; }"

      assert css =~
               ".#{class_name("outline", "2px solid blue", ":focus")}:focus { outline: 2px solid blue; }"
    end

    test ":active condition" do
      defmodule ActiveTest do
        use LiveStyle

        style(:button, %{
          transform: %{
            default: "scale(1)",
            ":active": "scale(0.95)"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("transform", "scale(1)")} { transform: scale(1); }"

      assert css =~
               ".#{class_name("transform", "scale(0.95)", ":active")}:active { transform: scale(0.95); }"
    end

    test ":disabled condition" do
      defmodule DisabledTest do
        use LiveStyle

        style(:button, %{
          opacity: %{
            default: "1",
            ":disabled": "0.5"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("opacity", "1")} { opacity: 1; }"
      assert css =~ ".#{class_name("opacity", "0.5", ":disabled")}:disabled { opacity: 0.5; }"
    end

    test "multiple pseudo-classes on same property" do
      defmodule MultiplePseudos do
        use LiveStyle

        style(:button, %{
          background_color: %{
            default: "gray",
            ":hover": "blue",
            ":active": "darkblue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "gray")} { background-color: gray; }"

      assert css =~
               ".#{class_name("background-color", "blue", ":hover")}:hover { background-color: blue; }"

      assert css =~
               ".#{class_name("background-color", "darkblue", ":active")}:active { background-color: darkblue; }"
    end

    test ":first-child condition" do
      defmodule FirstChildTest do
        use LiveStyle

        style(:item, %{
          margin_top: %{
            default: "10px",
            ":first-child": "0"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("margin-top", "10px")} { margin-top: 10px; }"

      assert css =~
               ".#{class_name("margin-top", "0", ":first-child")}:first-child { margin-top: 0; }"
    end

    test ":last-child condition" do
      defmodule LastChildTest do
        use LiveStyle

        style(:item, %{
          margin_bottom: %{
            default: "10px",
            ":last-child": "0"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("margin-bottom", "10px")} { margin-bottom: 10px; }"

      assert css =~
               ".#{class_name("margin-bottom", "0", ":last-child")}:last-child { margin-bottom: 0; }"
    end

    test ":nth-child() condition" do
      defmodule NthChildTest do
        use LiveStyle

        style(:row, %{
          background_color: %{
            default: "white",
            ":nth-child(odd)": "#f5f5f5"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "white")} { background-color: white; }"

      assert css =~
               ".#{class_name("background-color", "#f5f5f5", ":nth-child(odd)")}:nth-child(odd) { background-color: #f5f5f5; }"
    end

    test ":checked condition" do
      defmodule CheckedTest do
        use LiveStyle

        style(:checkbox, %{
          background_color: %{
            default: "white",
            ":checked": "blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "white")} { background-color: white; }"

      assert css =~
               ".#{class_name("background-color", "blue", ":checked")}:checked { background-color: blue; }"
    end

    test ":focus-visible condition" do
      defmodule FocusVisibleTest do
        use LiveStyle

        style(:button, %{
          outline: %{
            default: "none",
            ":focus-visible": "2px solid blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("outline", "none")} { outline: none; }"

      assert css =~
               ".#{class_name("outline", "2px solid blue", ":focus-visible")}:focus-visible { outline: 2px solid blue; }"
    end

    test ":focus-within condition" do
      defmodule FocusWithinTest do
        use LiveStyle

        style(:form_group, %{
          border_color: %{
            default: "gray",
            ":focus-within": "blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("border-color", "gray")} { border-color: gray; }"

      assert css =~
               ".#{class_name("border-color", "blue", ":focus-within")}:focus-within { border-color: blue; }"
    end
  end

  # ===========================================================================
  # Functional pseudo-classes
  # ===========================================================================

  describe "functional pseudo-classes" do
    test ":has() with class selector" do
      defmodule HasClassTest do
        use LiveStyle

        style(:parent, %{
          border: %{
            default: "1px solid gray",
            ":has(.error)": "1px solid red"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("border", "1px solid gray")} { border: 1px solid gray; }"

      assert css =~
               ".#{class_name("border", "1px solid red", ":has(.error)")}:has(.error) { border: 1px solid red; }"
    end

    test ":has() with hover" do
      defmodule HasHoverTest do
        use LiveStyle

        style(:container, %{
          background_color: %{
            default: "white",
            ":has(:hover)": "lightblue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "white")} { background-color: white; }"

      assert css =~
               ".#{class_name("background-color", "lightblue", ":has(:hover)")}:has(:hover) { background-color: lightblue; }"
    end

    test ":has() with sibling combinator" do
      defmodule HasSiblingTest do
        use LiveStyle

        style(:cell, %{
          background_color: %{
            default: "white",
            ":has(~ *:hover)": "yellow"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "white")} { background-color: white; }"

      assert css =~
               ".#{class_name("background-color", "yellow", ":has(~ *:hover)")}:has(~ *:hover) { background-color: yellow; }"
    end

    test ":not() with pseudo-class" do
      defmodule NotPseudoTest do
        use LiveStyle

        style(:button, %{
          cursor: %{
            default: "pointer",
            ":not(:disabled)": "pointer"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("cursor", "pointer")} { cursor: pointer; }"

      assert css =~
               ".#{class_name("cursor", "pointer", ":not(:disabled)")}:not(:disabled) { cursor: pointer; }"
    end

    test ":not() with class" do
      defmodule NotClassTest do
        use LiveStyle

        style(:link, %{
          opacity: %{
            default: "1",
            ":not(.active)": "0.7"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("opacity", "1")} { opacity: 1; }"

      assert css =~
               ".#{class_name("opacity", "0.7", ":not(.active)")}:not(.active) { opacity: 0.7; }"
    end

    test ":is() with multiple selectors" do
      defmodule IsMultipleTest do
        use LiveStyle

        style(:link, %{
          text_decoration: %{
            default: "none",
            ":is(:hover, :focus)": "underline"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("text-decoration", "none")} { text-decoration: none; }"

      assert css =~
               ".#{class_name("text-decoration", "underline", ":is(:hover, :focus)")}:is(:hover, :focus) { text-decoration: underline; }"
    end

    test ":where() for zero-specificity" do
      defmodule WhereTest do
        use LiveStyle

        style(:element, %{
          margin: %{
            default: "0",
            ":where(.spaced)": "1rem"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("margin", "0")} { margin: 0; }"

      assert css =~
               ".#{class_name("margin", "1rem", ":where(.spaced)")}:where(.spaced) { margin: 1rem; }"
    end

    test "combined :hover:not(:disabled)" do
      defmodule CombinedPseudoTest do
        use LiveStyle

        style(:button, %{
          background_color: %{
            default: "gray",
            ":hover:not(:disabled)": "blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("background-color", "gray")} { background-color: gray; }"

      assert css =~
               ".#{class_name("background-color", "blue", ":hover:not(:disabled)")}:hover:not(:disabled) { background-color: blue; }"
    end
  end

  # ===========================================================================
  # Media queries
  # ===========================================================================

  describe "media queries" do
    test "@media as condition" do
      defmodule MediaQueryTest do
        use LiveStyle

        style(:container, %{
          padding: %{
            default: "8px",
            "@media (min-width: 768px)": "16px"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("padding", "8px")} { padding: 8px; }"

      assert css =~
               "@media (min-width: 768px) { .#{class_name("padding", "16px", nil, "@media (min-width: 768px)")} { padding: 16px; } }"
    end

    test "multiple media queries" do
      defmodule MultipleMediaTest do
        use LiveStyle

        style(:container, %{
          width: %{
            default: "100%",
            "@media (min-width: 768px)": "750px",
            "@media (min-width: 1024px)": "970px"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("width", "100%")} { width: 100%; }"

      assert css =~
               "@media (min-width: 768px) { .#{class_name("width", "750px", nil, "@media (min-width: 768px)")} { width: 750px; } }"

      assert css =~
               "@media (min-width: 1024px) { .#{class_name("width", "970px", nil, "@media (min-width: 1024px)")} { width: 970px; } }"
    end
  end

  # ===========================================================================
  # Pseudo-elements
  # ===========================================================================

  describe "pseudo-elements" do
    test "::before" do
      defmodule BeforeTest do
        use LiveStyle

        style(:decorated, %{
          "::before": %{
            content: "'*'",
            color: "red"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("content", "'*'", "::before")}::before { content: '*'; }"
      assert css =~ ".#{class_name("color", "red", "::before")}::before { color: red; }"
    end

    test "::after" do
      defmodule AfterTest do
        use LiveStyle

        style(:decorated, %{
          "::after": %{
            content: "''",
            display: "block"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("content", "''", "::after")}::after { content: ''; }"
      assert css =~ ".#{class_name("display", "block", "::after")}::after { display: block; }"
    end

    test "::placeholder" do
      defmodule PlaceholderTest do
        use LiveStyle

        style(:input, %{
          "::placeholder": %{
            color: "gray",
            font_style: "italic"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~
               ".#{class_name("color", "gray", "::placeholder")}::placeholder { color: gray; }"

      assert css =~
               ".#{class_name("font-style", "italic", "::placeholder")}::placeholder { font-style: italic; }"
    end

    test "::selection" do
      defmodule SelectionTest do
        use LiveStyle

        style(:text, %{
          "::selection": %{
            background_color: "yellow",
            color: "black"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~
               ".#{class_name("background-color", "yellow", "::selection")}::selection { background-color: yellow; }"

      assert css =~ ".#{class_name("color", "black", "::selection")}::selection { color: black; }"
    end

    test "mixed properties and pseudo-elements" do
      defmodule MixedPseudoElementTest do
        use LiveStyle

        style(:input, %{
          color: "black",
          "::placeholder": %{
            color: "gray"
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ ".#{class_name("color", "black")} { color: black; }"

      assert css =~
               ".#{class_name("color", "gray", "::placeholder")}::placeholder { color: gray; }"
    end
  end

  # ===========================================================================
  # var/1 macro
  # ===========================================================================

  describe "var/1 macro" do
    test "generates CSS var() reference" do
      defmodule VarTest do
        use LiveStyle

        style(:test, %{
          color: var(:text_primary)
        })
      end

      css = LiveStyle.get_all_css()
      var = var_name(:text_primary)
      expected_class = class_name("color", "var(#{var})")
      assert css =~ ".#{expected_class} { color: var(#{var}); }"
    end

    test "same var produces same CSS variable name" do
      defmodule VarDeterministicTest do
        use LiveStyle

        style(:a, %{color: var(:text_primary)})
        style(:b, %{background_color: var(:text_primary)})
      end

      css = LiveStyle.get_all_css()
      var = var_name(:text_primary)
      # Both should reference the same CSS variable
      assert css =~ "color: var(#{var})"
      assert css =~ "background-color: var(#{var})"
    end
  end

  # ===========================================================================
  # first_that_works/1 macro
  # ===========================================================================

  describe "first_that_works/1 macro" do
    test "generates fallback CSS values" do
      defmodule FallbackTest do
        use LiveStyle

        style(:header, %{
          position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
        })
      end

      css = LiveStyle.get_all_css()
      # The class name uses pipe-joined values
      expected_class = class_name("position", "sticky|-webkit-sticky|fixed")

      assert css =~
               ".#{expected_class} { position: fixed; position: -webkit-sticky; position: sticky; }"
    end
  end

  # ===========================================================================
  # keyframes/2 macro
  # ===========================================================================

  describe "keyframes/2 macro" do
    test "defines keyframes animation" do
      defmodule KeyframesTest do
        use LiveStyle

        keyframes(:spin, %{
          from: %{transform: "rotate(0deg)"},
          to: %{transform: "rotate(360deg)"}
        })

        style(:spinner, %{
          animation_name: :spin
        })
      end

      css = LiveStyle.get_all_css()
      kf_name = keyframe_name(LiveStyleTest.KeyframesTest, :spin)

      assert css =~ "@keyframes #{kf_name} {"
      assert css =~ "from { transform: rotate(0deg); }"
      assert css =~ "to { transform: rotate(360deg); }"
      assert css =~ "animation-name: #{kf_name};"
    end
  end

  # ===========================================================================
  # style/1 function (generated)
  # ===========================================================================

  describe "style/1 function" do
    test "returns class string for single style" do
      defmodule StyleFuncSingle do
        use LiveStyle

        style(:base, %{display: "flex"})

        def get_class, do: style(:base)
      end

      # Class name should match the generated class
      expected_class = class_name("display", "flex")
      assert StyleFuncSingle.get_class() == expected_class
    end

    test "returns merged class string for multiple styles" do
      defmodule StyleFuncMultiple do
        use LiveStyle

        style(:base, %{display: "flex", color: "red"})
        style(:override, %{color: "blue"})

        def get_class, do: style([:base, :override])
      end

      classes = String.split(StyleFuncMultiple.get_class(), " ")
      # Should have display: flex class and color: blue class (override wins)
      assert class_name("display", "flex") in classes
      assert class_name("color", "blue") in classes
      # Should NOT have color: red (it was overridden)
      refute class_name("color", "red") in classes
    end

    test "filters out falsy values" do
      defmodule StyleFuncFilter do
        use LiveStyle

        style(:base, %{display: "flex"})
        style(:active, %{color: "blue"})

        def get_class(active?), do: style([:base, active? && :active])
      end

      active_classes = String.split(StyleFuncFilter.get_class(true), " ")
      inactive_classes = String.split(StyleFuncFilter.get_class(false), " ")

      assert length(active_classes) == 2
      assert length(inactive_classes) == 1
      assert class_name("display", "flex") in active_classes
      assert class_name("color", "blue") in active_classes
      assert class_name("display", "flex") in inactive_classes
    end
  end

  # ===========================================================================
  # CSS output structure
  # ===========================================================================

  describe "CSS output" do
    test "wraps rules in @layer live_style" do
      defmodule LayerTest do
        use LiveStyle
        style(:test, %{display: "flex"})
      end

      css = LiveStyle.get_all_css()
      assert String.starts_with?(css, "@layer live_style {")
      assert String.ends_with?(css, "}\n")
    end

    test "sorts rules by property priority" do
      defmodule PriorityTest do
        use LiveStyle

        style(:test, %{
          color: "red",
          display: "flex",
          z_index: 10
        })
      end

      css = LiveStyle.get_all_css()
      display_pos = :binary.match(css, "display: flex") |> elem(0)
      z_index_pos = :binary.match(css, "z-index: 10") |> elem(0)
      color_pos = :binary.match(css, "color: red") |> elem(0)

      # display (100) < z-index (610) < color (800)
      assert display_pos < z_index_pos
      assert z_index_pos < color_pos
    end
  end

  # ===========================================================================
  # clear/0
  # ===========================================================================

  describe "clear/0" do
    test "clears the manifest" do
      defmodule ClearTest do
        use LiveStyle
        style(:test, %{display: "flex"})
      end

      assert LiveStyle.get_all_css() =~ "display: flex"

      LiveStyle.clear()

      assert LiveStyle.get_all_css() == ""
    end
  end

  # ===========================================================================
  # LiveStyle.When contextual selectors
  # ===========================================================================

  describe "LiveStyle.When" do
    import LiveStyle.When

    test "ancestor/1 generates correct selector" do
      selector = ":where(.x-marker:hover *)"

      defmodule AncestorTest do
        use LiveStyle

        style(:card, %{
          transform: %{
            :default => "translateX(0)",
            ":where(.x-marker:hover *)" => "translateX(10px)"
          }
        })
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("transform", "translateX(10px)", selector)

      assert css =~ ".#{expected_class}#{selector} { transform: translateX(10px); }"
    end

    test "descendant/1 generates correct selector" do
      selector = ":where(:has(.x-marker:focus))"

      defmodule DescendantTest do
        use LiveStyle

        style(:container, %{
          border_color: %{
            :default => "gray",
            ":where(:has(.x-marker:focus))" => "blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("border-color", "blue", selector)

      assert css =~ ".#{expected_class}#{selector} { border-color: blue; }"
    end

    test "sibling_before/1 generates correct selector" do
      selector = ":where(.x-marker:hover ~ *)"

      defmodule SiblingBeforeTest do
        use LiveStyle

        style(:item, %{
          background_color: %{
            :default => "white",
            ":where(.x-marker:hover ~ *)" => "lightblue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("background-color", "lightblue", selector)

      assert css =~ ".#{expected_class}#{selector} { background-color: lightblue; }"
    end

    test "sibling_after/1 generates correct selector" do
      selector = ":where(:has(~ .x-marker:focus))"

      defmodule SiblingAfterTest do
        use LiveStyle

        style(:label, %{
          color: %{
            :default => "black",
            ":where(:has(~ .x-marker:focus))" => "blue"
          }
        })
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("color", "blue", selector)

      assert css =~ ".#{expected_class}#{selector} { color: blue; }"
    end

    test "any_sibling/1 generates correct selector" do
      selector = ":where(.x-marker:hover ~ *, :has(~ .x-marker:hover))"

      defmodule AnySiblingTest do
        use LiveStyle

        style(:tab, %{
          opacity: %{
            :default => "1",
            ":where(.x-marker:hover ~ *, :has(~ .x-marker:hover))" => "0.7"
          }
        })
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("opacity", "0.7", selector)

      assert css =~ ".#{expected_class}#{selector} { opacity: 0.7; }"
    end

    test "custom marker with ancestor/2" do
      row_marker = LiveStyle.define_marker(:row)
      selector = ":where(.#{row_marker}:hover *)"

      defmodule CustomMarkerTest do
        use LiveStyle

        # Use the marker value directly as string key
        @row_marker LiveStyle.define_marker(:row)

        style(:cell, %{
          background_color: %{
            :default => "white",
            ":where(.x-marker-674754d:hover *)" => "lightblue"
          }
        })

        def row_marker, do: @row_marker
      end

      css = LiveStyle.get_all_css()
      expected_class = class_name("background-color", "lightblue", selector)

      assert css =~ ".#{expected_class}#{selector} { background-color: lightblue; }"
    end

    test "When helper functions generate correct selectors" do
      assert ancestor(":hover") == ":where(.x-marker:hover *)"
      assert descendant(":focus") == ":where(:has(.x-marker:focus))"
      assert sibling_before(":hover") == ":where(.x-marker:hover ~ *)"
      assert sibling_after(":focus") == ":where(:has(~ .x-marker:focus))"
      assert any_sibling(":hover") == ":where(.x-marker:hover ~ *, :has(~ .x-marker:hover))"
    end

    test "When helpers with custom marker" do
      marker = LiveStyle.define_marker(:card)
      assert ancestor(":hover", marker) == ":where(.#{marker}:hover *)"
      assert descendant(":focus", marker) == ":where(:has(.#{marker}:focus))"
    end

    test "default_marker/0 returns the default marker class" do
      assert LiveStyle.default_marker() == "x-marker"
    end

    test "define_marker/1 returns a unique marker class" do
      marker1 = LiveStyle.define_marker(:card)
      marker2 = LiveStyle.define_marker(:row)
      marker1_again = LiveStyle.define_marker(:card)

      # Different names produce different markers
      assert marker1 != marker2

      # Same name produces same marker (deterministic)
      assert marker1 == marker1_again

      # Markers have expected format
      assert String.starts_with?(marker1, "x-marker-")
      assert String.starts_with?(marker2, "x-marker-")
    end

    test "conditions/1 allows module attributes as condition keys" do
      defmodule ConditionsTest do
        use LiveStyle
        import LiveStyle.When

        @row_marker LiveStyle.define_marker(:test_row)
        @row_hover ancestor(":hover", @row_marker)
        @col_hover ":where(:has(td:nth-of-type(1):hover))"

        style(:cell, %{
          background_color:
            conditions([
              {:default, "white"},
              {@row_hover, "lightblue"},
              {@col_hover, "lightblue"},
              {":hover", "blue"}
            ])
        })

        def row_marker, do: @row_marker
        def row_hover, do: @row_hover
        def col_hover, do: @col_hover
      end

      css = LiveStyle.get_all_css()

      # Check default value
      assert css =~ "background-color: white"

      # Check row hover selector
      row_hover = ConditionsTest.row_hover()
      row_class = class_name("background-color", "lightblue", row_hover)
      assert css =~ ".#{row_class}#{row_hover} { background-color: lightblue; }"

      # Check column hover selector
      col_hover = ConditionsTest.col_hover()
      col_class = class_name("background-color", "lightblue", col_hover)
      assert css =~ ".#{col_class}#{col_hover} { background-color: lightblue; }"

      # Check direct hover
      hover_class = class_name("background-color", "blue", ":hover")
      assert css =~ ".#{hover_class}:hover { background-color: blue; }"
    end
  end

  # ===========================================================================
  # Nested pseudo-class conditions
  # ===========================================================================

  describe "nested pseudo-class conditions" do
    test "nested conditions combine pseudo-classes" do
      defmodule NestedConditionsTest do
        use LiveStyle
        import LiveStyle.When

        @col_hover ancestor(":has(td:nth-of-type(2):hover)")

        style(:cell, %{
          background_color:
            conditions([
              {:default, "transparent"},
              {":nth-child(2)",
               %{
                 :default => nil,
                 @col_hover => "#2266cc77"
               }}
            ])
        })

        def col_hover, do: @col_hover
      end

      css = LiveStyle.get_all_css()
      col_hover = NestedConditionsTest.col_hover()

      # Should generate combined selector: :nth-child(2):where(.x-marker:has(...) *)
      combined_selector = ":nth-child(2)#{col_hover}"
      expected_class = class_name("background-color", "#2266cc77", combined_selector)

      assert css =~ ".#{expected_class}#{combined_selector} { background-color: #2266cc77; }"
    end

    test "nested conditions with direct hover" do
      defmodule NestedHoverTest do
        use LiveStyle

        style(:button, %{
          background_color: %{
            :default => "gray",
            ":hover" => %{
              :default => "blue",
              ":disabled" => "gray"
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      # Default
      assert css =~ "background-color: gray"

      # :hover default
      hover_class = class_name("background-color", "blue", ":hover")
      assert css =~ ".#{hover_class}:hover { background-color: blue; }"

      # :hover:disabled combined
      combined_selector = ":hover:disabled"
      combined_class = class_name("background-color", "gray", combined_selector)
      assert css =~ ".#{combined_class}#{combined_selector} { background-color: gray; }"
    end

    test "nested conditions with multiple nth-child columns" do
      defmodule MultiColumnTest do
        use LiveStyle
        import LiveStyle.When

        @col2_hover ancestor(":has(td:nth-of-type(2):hover)")
        @col3_hover ancestor(":has(td:nth-of-type(3):hover)")

        style(:cell, %{
          opacity:
            conditions([
              {:default, "1"},
              {":nth-child(2)",
               %{
                 :default => nil,
                 @col2_hover => "1"
               }},
              {":nth-child(3)",
               %{
                 :default => nil,
                 @col3_hover => "1"
               }}
            ])
        })

        def col2_hover, do: @col2_hover
        def col3_hover, do: @col3_hover
      end

      css = LiveStyle.get_all_css()

      # Column 2
      col2_hover = MultiColumnTest.col2_hover()
      col2_selector = ":nth-child(2)#{col2_hover}"
      col2_class = class_name("opacity", "1", col2_selector)
      assert css =~ ".#{col2_class}#{col2_selector} { opacity: 1; }"

      # Column 3
      col3_hover = MultiColumnTest.col3_hover()
      col3_selector = ":nth-child(3)#{col3_hover}"
      col3_class = class_name("opacity", "1", col3_selector)
      assert css =~ ".#{col3_class}#{col3_selector} { opacity: 1; }"
    end

    test "nested conditions preserve parent pseudo-class in default" do
      defmodule NestedDefaultTest do
        use LiveStyle

        style(:item, %{
          color: %{
            :default => "black",
            ":first-child" => %{
              :default => "red",
              ":hover" => "darkred"
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      # Default
      default_class = class_name("color", "black")
      assert css =~ ".#{default_class} { color: black; }"

      # :first-child default
      first_child_class = class_name("color", "red", ":first-child")
      assert css =~ ".#{first_child_class}:first-child { color: red; }"

      # :first-child:hover combined
      combined_selector = ":first-child:hover"
      combined_class = class_name("color", "darkred", combined_selector)
      assert css =~ ".#{combined_class}#{combined_selector} { color: darkred; }"
    end

    test "deeply nested conditions" do
      defmodule DeeplyNestedTest do
        use LiveStyle

        style(:element, %{
          opacity: %{
            :default => "1",
            ":hover" => %{
              :default => "0.9",
              ":focus" => %{
                :default => "0.8"
              }
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      # Default
      assert css =~ "opacity: 1"

      # :hover
      hover_class = class_name("opacity", "0.9", ":hover")
      assert css =~ ".#{hover_class}:hover { opacity: 0.9; }"

      # :hover:focus
      combined_class = class_name("opacity", "0.8", ":hover:focus")
      assert css =~ ".#{combined_class}:hover:focus { opacity: 0.8; }"
    end
  end
end
