defmodule LiveStyle.ThemesTest do
  @moduledoc """
  Comprehensive tests for LiveStyle's css_theme macro (StyleX's createTheme).

  These tests verify that LiveStyle's theme implementation matches StyleX's
  createTheme API behavior for:
  - Basic theme overrides
  - Themes with media query conditionals
  - Themes with nested @-rules
  - Multiple themes for the same variable set
  - Theme class generation

  Reference: stylex/packages/@stylexjs/babel-plugin/__tests__/transform-stylex-createTheme-test.js
  """
  use LiveStyle.TestCase, async: true

  # ===========================================================================
  # Test Modules - Basic themes
  # ===========================================================================

  defmodule BaseVars do
    use LiveStyle

    css_vars(:colors,
      color: "blue",
      other_color: "grey",
      radius: "10px"
    )
  end

  defmodule BasicTheme do
    use LiveStyle

    css_theme({BaseVars, :colors}, :custom,
      color: "green",
      other_color: "antiquewhite",
      radius: "6px"
    )
  end

  # ===========================================================================
  # Test Modules - Themes with media query conditionals
  # ===========================================================================

  defmodule ConditionalBaseVars do
    use LiveStyle

    css_vars(:colors,
      color: %{
        :default => "blue",
        "@media (prefers-color-scheme: dark)" => "lightblue",
        "@media print" => "white"
      },
      other_color: %{
        :default => "grey",
        "@media (prefers-color-scheme: dark)" => "rgba(0, 0, 0, 0.8)"
      },
      radius: "10px"
    )
  end

  defmodule ConditionalTheme do
    use LiveStyle

    css_theme({ConditionalBaseVars, :colors}, :green_theme,
      color: %{
        :default => "green",
        "@media (prefers-color-scheme: dark)" => "lightgreen",
        "@media print" => "transparent"
      },
      other_color: %{
        :default => "antiquewhite",
        "@media (prefers-color-scheme: dark)" => "floralwhite"
      },
      radius: "6px"
    )
  end

  # ===========================================================================
  # Test Modules - Themes with nested @-rules
  # ===========================================================================

  defmodule NestedBaseVars do
    use LiveStyle

    css_vars(:colors,
      color: "blue",
      other_color: "grey"
    )
  end

  defmodule NestedTheme do
    use LiveStyle

    css_theme({NestedBaseVars, :colors}, :nested,
      color: %{
        :default => "green",
        "@media (prefers-color-scheme: dark)" => "lightgreen"
      },
      other_color: %{
        :default => "antiquewhite",
        "@media (prefers-color-scheme: dark)" => %{
          :default => "floralwhite",
          "@supports (color: oklab(0 0 0))" => "oklab(0.7 -0.3 -0.4)"
        }
      }
    )
  end

  # ===========================================================================
  # Test Modules - Multiple themes for same variable set
  # ===========================================================================

  defmodule SharedVars do
    use LiveStyle

    css_vars(:brand,
      primary: "blue",
      secondary: "green",
      accent: "purple"
    )
  end

  defmodule DarkTheme do
    use LiveStyle

    css_theme({SharedVars, :brand}, :dark,
      primary: "lightblue",
      secondary: "lightgreen",
      accent: "lavender"
    )
  end

  defmodule HighContrastTheme do
    use LiveStyle

    css_theme({SharedVars, :brand}, :high_contrast,
      primary: "white",
      secondary: "yellow",
      accent: "cyan"
    )
  end

  defmodule WarmTheme do
    use LiveStyle

    css_theme({SharedVars, :brand}, :warm,
      primary: "orange",
      secondary: "coral",
      accent: "gold"
    )
  end

  # ===========================================================================
  # Test Modules - Partial theme overrides
  # ===========================================================================

  defmodule FullVars do
    use LiveStyle

    css_vars(:ui,
      text_color: "black",
      bg_color: "white",
      border_color: "gray",
      shadow_color: "rgba(0,0,0,0.1)"
    )
  end

  defmodule PartialTheme do
    use LiveStyle

    # Only override some variables, not all
    css_theme({FullVars, :ui}, :partial,
      text_color: "blue",
      bg_color: "lightblue"
      # border_color and shadow_color are not overridden
    )
  end

  # ===========================================================================
  # Test Modules - Theme CSS output format
  # ===========================================================================

  defmodule CSSFormatVars do
    use LiveStyle

    css_vars(:test,
      color: "red",
      size: "10px"
    )
  end

  defmodule CSSFormatTheme do
    use LiveStyle

    css_theme({CSSFormatVars, :test}, :format_test,
      color: "blue",
      size: "20px"
    )
  end

  # ===========================================================================
  # Test Modules - Cross-module theme references
  # ===========================================================================

  defmodule ExternalVars do
    use LiveStyle

    css_vars(:external,
      main_color: "navy"
    )
  end

  defmodule ExternalTheme do
    use LiveStyle
    alias LiveStyle.ThemesTest.ExternalVars

    css_theme({ExternalVars, :external}, :alt, main_color: "teal")
  end

  # ===========================================================================
  # Test Modules - Theme with typed variables
  # ===========================================================================

  defmodule TypedBaseVars do
    use LiveStyle
    import LiveStyle.Types

    css_vars(:typed,
      primary_color: color("blue"),
      rotation: angle("0deg"),
      duration: time("200ms")
    )
  end

  defmodule TypedTheme do
    use LiveStyle

    css_theme({TypedBaseVars, :typed}, :animated,
      primary_color: "red",
      rotation: "45deg",
      duration: "500ms"
    )
  end

  # ===========================================================================
  # Test Modules - Edge cases
  # ===========================================================================

  defmodule EdgeVars do
    use LiveStyle

    css_vars(:edge,
      empty_string: "",
      zero: "0",
      complex_value: "rgba(0, 0, 0, 0.5)"
    )
  end

  defmodule EdgeTheme do
    use LiveStyle

    css_theme({EdgeVars, :edge}, :edge_theme,
      empty_string: "not-empty",
      zero: "1",
      complex_value: "hsla(0, 100%, 50%, 0.75)"
    )
  end

  # ===========================================================================
  # Tests - Basic themes
  # ===========================================================================

  describe "basic themes" do
    test "theme is stored in manifest" do
      theme = LiveStyle.get_metadata(BasicTheme, {:theme, :colors, :custom})

      assert theme != nil
      assert theme.css_name != nil
    end

    test "theme has overrides for all specified variables" do
      theme = LiveStyle.get_metadata(BasicTheme, {:theme, :colors, :custom})

      # Get original variable names
      color_var = LiveStyle.get_metadata(BaseVars, {:var, :colors, :color})
      other_color_var = LiveStyle.get_metadata(BaseVars, {:var, :colors, :other_color})
      radius_var = LiveStyle.get_metadata(BaseVars, {:var, :colors, :radius})

      # Theme should override all three
      assert theme.overrides[color_var.css_name] == "green"
      assert theme.overrides[other_color_var.css_name] == "antiquewhite"
      assert theme.overrides[radius_var.css_name] == "6px"
    end

    test "theme generates unique class name" do
      theme = LiveStyle.get_metadata(BasicTheme, {:theme, :colors, :custom})

      # Class name should be a hashed value (LiveStyle uses 't' prefix for themes)
      assert theme.css_name =~ ~r/^t[a-z0-9]+$/
    end
  end

  # ===========================================================================
  # Tests - Themes with media query conditionals
  # ===========================================================================

  describe "themes with media query conditionals" do
    test "theme stores conditional overrides" do
      theme = LiveStyle.get_metadata(ConditionalTheme, {:theme, :colors, :green_theme})

      assert theme != nil
      assert theme.overrides != nil
    end

    test "theme with conditionals generates appropriate CSS" do
      css = generate_css()
      theme = LiveStyle.get_metadata(ConditionalTheme, {:theme, :colors, :green_theme})

      # Theme class should appear in CSS
      assert css =~ theme.css_name
    end
  end

  # ===========================================================================
  # Tests - Themes with nested @-rules
  # ===========================================================================

  describe "themes with nested @-rules" do
    test "theme stores nested conditional overrides" do
      theme = LiveStyle.get_metadata(NestedTheme, {:theme, :colors, :nested})

      assert theme != nil
      # The nested structure should be preserved
      assert is_map(theme.overrides)
    end
  end

  # ===========================================================================
  # Tests - Multiple themes for same variable set
  # ===========================================================================

  describe "multiple themes for same variable set" do
    test "each theme gets unique class name" do
      dark = LiveStyle.get_metadata(DarkTheme, {:theme, :brand, :dark})
      high_contrast = LiveStyle.get_metadata(HighContrastTheme, {:theme, :brand, :high_contrast})
      warm = LiveStyle.get_metadata(WarmTheme, {:theme, :brand, :warm})

      names = [dark.css_name, high_contrast.css_name, warm.css_name]
      assert length(Enum.uniq(names)) == 3
    end

    test "all themes are stored in manifest" do
      assert LiveStyle.get_metadata(DarkTheme, {:theme, :brand, :dark}) != nil
      assert LiveStyle.get_metadata(HighContrastTheme, {:theme, :brand, :high_contrast}) != nil
      assert LiveStyle.get_metadata(WarmTheme, {:theme, :brand, :warm}) != nil
    end

    test "themes can be retrieved via LiveStyle.Theme.lookup!/3" do
      dark_name = LiveStyle.Theme.lookup!(DarkTheme, :brand, :dark)
      high_contrast_name = LiveStyle.Theme.lookup!(HighContrastTheme, :brand, :high_contrast)
      warm_name = LiveStyle.Theme.lookup!(WarmTheme, :brand, :warm)

      assert is_binary(dark_name)
      assert is_binary(high_contrast_name)
      assert is_binary(warm_name)

      assert dark_name != high_contrast_name
      assert high_contrast_name != warm_name
    end
  end

  # ===========================================================================
  # Tests - Partial theme overrides
  # ===========================================================================

  describe "partial theme overrides" do
    test "partial theme only has overrides for specified vars" do
      theme = LiveStyle.get_metadata(PartialTheme, {:theme, :ui, :partial})

      text_var = LiveStyle.get_metadata(FullVars, {:var, :ui, :text_color})
      bg_var = LiveStyle.get_metadata(FullVars, {:var, :ui, :bg_color})
      border_var = LiveStyle.get_metadata(FullVars, {:var, :ui, :border_color})
      shadow_var = LiveStyle.get_metadata(FullVars, {:var, :ui, :shadow_color})

      # Should have overrides for text and bg
      assert theme.overrides[text_var.css_name] == "blue"
      assert theme.overrides[bg_var.css_name] == "lightblue"

      # Should NOT have overrides for border and shadow
      refute Map.has_key?(theme.overrides, border_var.css_name)
      refute Map.has_key?(theme.overrides, shadow_var.css_name)
    end
  end

  # ===========================================================================
  # Tests - Theme CSS output format
  # ===========================================================================

  describe "theme CSS output format" do
    test "theme CSS contains class selector" do
      css = generate_css()
      theme = LiveStyle.get_metadata(CSSFormatTheme, {:theme, :test, :format_test})

      # StyleX format: .x10yrbfs, .x10yrbfs:root{...}
      assert css =~ ".#{theme.css_name}"
    end

    test "theme CSS sets CSS variable values" do
      css = generate_css()

      color_var = LiveStyle.get_metadata(CSSFormatVars, {:var, :test, :color})
      size_var = LiveStyle.get_metadata(CSSFormatVars, {:var, :test, :size})

      # Should have variable assignments in theme CSS
      assert css =~ "#{color_var.css_name}:blue"
      assert css =~ "#{size_var.css_name}:20px"
    end
  end

  # ===========================================================================
  # Tests - Cross-module theme references
  # ===========================================================================

  describe "cross-module theme references" do
    test "can create theme for variables in another module" do
      theme = LiveStyle.get_metadata(ExternalTheme, {:theme, :external, :alt})

      assert theme != nil

      # Should reference the correct variable
      main_var = LiveStyle.get_metadata(ExternalVars, {:var, :external, :main_color})
      assert theme.overrides[main_var.css_name] == "teal"
    end
  end

  # ===========================================================================
  # Tests - Theme with typed variables
  # ===========================================================================

  describe "theme with typed variables" do
    test "theme can override typed variables" do
      theme = LiveStyle.get_metadata(TypedTheme, {:theme, :typed, :animated})

      assert theme != nil

      color_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :primary_color})
      rotation_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :rotation})
      duration_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :duration})

      # Theme should have overrides
      assert theme.overrides[color_var.css_name] == "red"
      assert theme.overrides[rotation_var.css_name] == "45deg"
      assert theme.overrides[duration_var.css_name] == "500ms"
    end

    test "typed variables retain their type even when themed" do
      color_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :primary_color})
      rotation_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :rotation})
      duration_var = LiveStyle.get_metadata(TypedBaseVars, {:var, :typed, :duration})

      # Original types should still be present
      assert color_var.type.syntax == "<color>"
      assert rotation_var.type.syntax == "<angle>"
      assert duration_var.type.syntax == "<time>"
    end
  end

  # ===========================================================================
  # Tests - Edge cases
  # ===========================================================================

  describe "edge cases" do
    test "theme can override empty string values" do
      theme = LiveStyle.get_metadata(EdgeTheme, {:theme, :edge, :edge_theme})
      var = LiveStyle.get_metadata(EdgeVars, {:var, :edge, :empty_string})

      assert theme.overrides[var.css_name] == "not-empty"
    end

    test "theme can override zero values" do
      theme = LiveStyle.get_metadata(EdgeTheme, {:theme, :edge, :edge_theme})
      var = LiveStyle.get_metadata(EdgeVars, {:var, :edge, :zero})

      assert theme.overrides[var.css_name] == "1"
    end

    test "theme can override complex CSS values" do
      theme = LiveStyle.get_metadata(EdgeTheme, {:theme, :edge, :edge_theme})
      var = LiveStyle.get_metadata(EdgeVars, {:var, :edge, :complex_value})

      assert theme.overrides[var.css_name] == "hsla(0, 100%, 50%, 0.75)"
    end
  end
end
