defmodule LiveStyle.PseudoElementsTest do
  @moduledoc """
  Tests for additional pseudo-elements beyond ::before, ::after, ::placeholder.

  These tests verify StyleX-compatible pseudo-element handling for:
  - ::marker (list markers)
  - ::selection (selected text)
  - ::backdrop (dialog/fullscreen backdrop)
  - ::first-letter and ::first-line (typography)
  - ::file-selector-button (file input button)
  - ::-webkit-scrollbar variants
  - ::cue (video captions)

  ## StyleX Reference
  All pseudo-elements have base priority 8000 (3000 for property + 5000 for pseudo-element).
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Test Modules - Basic Pseudo-Elements
  # ============================================================================

  defmodule MarkerStyles do
    use LiveStyle

    css_class(:marker,
      "::marker": [
        color: "red",
        font_size: "1.2em"
      ]
    )
  end

  defmodule SelectionStyles do
    use LiveStyle

    css_class(:selection,
      "::selection": [
        background_color: "yellow",
        color: "black"
      ]
    )
  end

  defmodule BackdropStyles do
    use LiveStyle

    css_class(:backdrop,
      "::backdrop": [
        background_color: "rgba(0,0,0,0.7)"
      ]
    )
  end

  defmodule FirstLetterLineStyles do
    use LiveStyle

    css_class(:first_letter,
      "::first-letter": [
        font_size: "2em",
        font_weight: "bold"
      ]
    )

    css_class(:first_line,
      "::first-line": [
        font_weight: "bold",
        text_decoration: "underline"
      ]
    )
  end

  defmodule FileSelectorStyles do
    use LiveStyle

    css_class(:file_button,
      "::file-selector-button": [
        background_color: "blue",
        color: "white",
        padding: "8px 16px"
      ]
    )
  end

  defmodule WebkitScrollbarStyles do
    use LiveStyle

    css_class(:scrollbar,
      "::-webkit-scrollbar": [
        width: "8px"
      ]
    )

    css_class(:scrollbar_thumb,
      "::-webkit-scrollbar-thumb": [
        background_color: "gray",
        border_radius: "4px"
      ]
    )

    css_class(:scrollbar_track,
      "::-webkit-scrollbar-track": [
        background_color: "#f1f1f1"
      ]
    )
  end

  defmodule CueStyles do
    use LiveStyle

    css_class(:cue,
      "::cue": [
        color: "white",
        background_color: "black"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Rare Pseudo-Elements
  # ============================================================================

  defmodule GrammarErrorStyles do
    use LiveStyle

    css_class(:grammar_error,
      "::grammar-error": [
        text_decoration: "underline wavy red"
      ]
    )
  end

  defmodule SpellingErrorStyles do
    use LiveStyle

    css_class(:spelling_error,
      "::spelling-error": [
        text_decoration: "underline wavy blue"
      ]
    )
  end

  defmodule TargetTextStyles do
    use LiveStyle

    css_class(:target_text,
      "::target-text": [
        background_color: "yellow"
      ]
    )
  end

  # ============================================================================
  # Test Modules - Pseudo-Element with Pseudo-Class
  # ============================================================================

  defmodule PseudoElementWithPseudo do
    use LiveStyle

    # ::selection:window-inactive - selection in inactive window
    css_class(:selection_hover,
      "::selection": [
        background_color: [
          default: "blue",
          ":hover": "darkblue"
        ]
      ]
    )
  end

  # ============================================================================
  # Tests - Basic Pseudo-Elements
  # ============================================================================

  describe "::marker pseudo-element" do
    test "generates CSS with ::marker" do
      rule = LiveStyle.get_metadata(MarkerStyles, {:class, :marker})

      # color::marker
      color_meta = rule.atomic_classes["color::marker"]
      assert color_meta.ltr =~ "::marker{color:red}"
      assert color_meta.priority == 8000

      # font-size::marker
      font_meta = rule.atomic_classes["font-size::marker"]
      assert font_meta.ltr =~ "::marker{font-size:1.2em}"
      assert font_meta.priority == 8000
    end
  end

  describe "::selection pseudo-element" do
    test "generates CSS with ::selection" do
      rule = LiveStyle.get_metadata(SelectionStyles, {:class, :selection})

      # background-color::selection
      bg_meta = rule.atomic_classes["background-color::selection"]
      assert bg_meta.ltr =~ "::selection{background-color:yellow}"
      assert bg_meta.priority == 8000

      # color::selection
      color_meta = rule.atomic_classes["color::selection"]
      assert color_meta.ltr =~ "::selection{color:black}"
      assert color_meta.priority == 8000
    end
  end

  describe "::backdrop pseudo-element" do
    test "generates CSS with ::backdrop" do
      rule = LiveStyle.get_metadata(BackdropStyles, {:class, :backdrop})

      bg_meta = rule.atomic_classes["background-color::backdrop"]
      # Note: StyleX removes leading zeros from decimal values (0.7 -> .7)
      assert bg_meta.ltr =~ "::backdrop{background-color:rgba(0,0,0,.7)}"
      assert bg_meta.priority == 8000
    end
  end

  describe "::first-letter and ::first-line pseudo-elements" do
    test "generates CSS with ::first-letter" do
      rule = LiveStyle.get_metadata(FirstLetterLineStyles, {:class, :first_letter})

      font_size = rule.atomic_classes["font-size::first-letter"]
      assert font_size.ltr =~ "::first-letter{font-size:2em}"
      assert font_size.priority == 8000

      font_weight = rule.atomic_classes["font-weight::first-letter"]
      assert font_weight.ltr =~ "::first-letter{font-weight:bold}"
      assert font_weight.priority == 8000
    end

    test "generates CSS with ::first-line" do
      rule = LiveStyle.get_metadata(FirstLetterLineStyles, {:class, :first_line})

      font_weight = rule.atomic_classes["font-weight::first-line"]
      assert font_weight.ltr =~ "::first-line{font-weight:bold}"
      assert font_weight.priority == 8000

      text_dec = rule.atomic_classes["text-decoration::first-line"]
      assert text_dec.ltr =~ "::first-line{text-decoration:underline}"
      # text-decoration is a shorthand (priority 2000), so 2000 + 5000 = 7000
      assert text_dec.priority == 7000
    end
  end

  describe "::file-selector-button pseudo-element" do
    test "generates CSS with ::file-selector-button" do
      rule = LiveStyle.get_metadata(FileSelectorStyles, {:class, :file_button})

      bg_meta = rule.atomic_classes["background-color::file-selector-button"]
      assert bg_meta.ltr =~ "::file-selector-button{background-color:blue}"
      assert bg_meta.priority == 8000

      color_meta = rule.atomic_classes["color::file-selector-button"]
      assert color_meta.ltr =~ "::file-selector-button{color:white}"
      assert color_meta.priority == 8000
    end
  end

  describe "::-webkit-scrollbar pseudo-elements" do
    test "generates CSS with ::-webkit-scrollbar" do
      rule = LiveStyle.get_metadata(WebkitScrollbarStyles, {:class, :scrollbar})

      width_meta = rule.atomic_classes["width::-webkit-scrollbar"]
      assert width_meta.ltr =~ "::-webkit-scrollbar{width:8px}"
      assert width_meta.priority == 9000
    end

    test "generates CSS with ::-webkit-scrollbar-thumb" do
      rule = LiveStyle.get_metadata(WebkitScrollbarStyles, {:class, :scrollbar_thumb})

      bg_meta = rule.atomic_classes["background-color::-webkit-scrollbar-thumb"]
      assert bg_meta.ltr =~ "::-webkit-scrollbar-thumb{background-color:gray}"
      assert bg_meta.priority == 8000
    end

    test "generates CSS with ::-webkit-scrollbar-track" do
      rule = LiveStyle.get_metadata(WebkitScrollbarStyles, {:class, :scrollbar_track})

      bg_meta = rule.atomic_classes["background-color::-webkit-scrollbar-track"]
      assert bg_meta.ltr =~ "::-webkit-scrollbar-track{background-color:#f1f1f1}"
      assert bg_meta.priority == 8000
    end
  end

  describe "::cue pseudo-element" do
    test "generates CSS with ::cue" do
      rule = LiveStyle.get_metadata(CueStyles, {:class, :cue})

      color_meta = rule.atomic_classes["color::cue"]
      assert color_meta.ltr =~ "::cue{color:white}"
      assert color_meta.priority == 8000

      bg_meta = rule.atomic_classes["background-color::cue"]
      assert bg_meta.ltr =~ "::cue{background-color:black}"
      assert bg_meta.priority == 8000
    end
  end

  # ============================================================================
  # Tests - Rare Pseudo-Elements
  # ============================================================================

  describe "::grammar-error pseudo-element" do
    test "generates CSS with ::grammar-error" do
      rule = LiveStyle.get_metadata(GrammarErrorStyles, {:class, :grammar_error})

      text_dec = rule.atomic_classes["text-decoration::grammar-error"]
      assert text_dec.ltr =~ "::grammar-error{text-decoration:underline wavy red}"
      # text-decoration is a shorthand (priority 2000), so 2000 + 5000 = 7000
      assert text_dec.priority == 7000
    end
  end

  describe "::spelling-error pseudo-element" do
    test "generates CSS with ::spelling-error" do
      rule = LiveStyle.get_metadata(SpellingErrorStyles, {:class, :spelling_error})

      text_dec = rule.atomic_classes["text-decoration::spelling-error"]
      assert text_dec.ltr =~ "::spelling-error{text-decoration:underline wavy blue}"
      # text-decoration is a shorthand (priority 2000), so 2000 + 5000 = 7000
      assert text_dec.priority == 7000
    end
  end

  describe "::target-text pseudo-element" do
    test "generates CSS with ::target-text" do
      rule = LiveStyle.get_metadata(TargetTextStyles, {:class, :target_text})

      bg_meta = rule.atomic_classes["background-color::target-text"]
      assert bg_meta.ltr =~ "::target-text{background-color:yellow}"
      assert bg_meta.priority == 8000
    end
  end

  # ============================================================================
  # Tests - Pseudo-Element with Pseudo-Class
  # ============================================================================

  describe "pseudo-element with pseudo-class" do
    test "generates CSS with ::selection and :hover" do
      rule = LiveStyle.get_metadata(PseudoElementWithPseudo, {:class, :selection_hover})

      # Default ::selection
      default_meta = rule.atomic_classes["background-color::selection"]
      assert default_meta.ltr =~ "::selection{background-color:blue}"
      assert default_meta.priority == 8000

      # ::selection:hover
      hover_meta = rule.atomic_classes["background-color::selection:hover"]
      assert hover_meta.ltr =~ "::selection:hover{background-color:darkblue}"
      # Priority: 8000 (::selection) + 130 (:hover) = 8130
      assert hover_meta.priority == 8130
    end
  end

  # ============================================================================
  # Tests - Priority System
  # ============================================================================

  describe "pseudo-element priority system" do
    test "all pseudo-elements have base priority 8000" do
      # Check marker
      marker_rule = LiveStyle.get_metadata(MarkerStyles, {:class, :marker})
      assert marker_rule.atomic_classes["color::marker"].priority == 8000

      # Check selection
      selection_rule = LiveStyle.get_metadata(SelectionStyles, {:class, :selection})
      assert selection_rule.atomic_classes["color::selection"].priority == 8000

      # Check backdrop
      backdrop_rule = LiveStyle.get_metadata(BackdropStyles, {:class, :backdrop})
      assert backdrop_rule.atomic_classes["background-color::backdrop"].priority == 8000
    end
  end

  # ============================================================================
  # Tests - CSS Output Format
  # ============================================================================

  describe "css output format" do
    test "pseudo-element CSS is properly formatted" do
      rule = LiveStyle.get_metadata(MarkerStyles, {:class, :marker})

      # Format should be: .{class}::{pseudo-element}{property:value}
      color_meta = rule.atomic_classes["color::marker"]
      assert color_meta.ltr =~ ~r/^\.[a-z0-9]+::marker\{color:red\}$/
    end
  end
end
