defmodule LiveStyle.VarsTest do
  @moduledoc """
  Tests for CSS variables (css_vars) and themes (css_theme).

  These tests mirror StyleX's transform-stylex-defineVars-test.js and
  transform-stylex-createTheme-test.js to ensure LiveStyle handles CSS
  variables the same way StyleX does.
  """
  use LiveStyle.TestCase, async: true

  # ============================================================================
  # Basic CSS Variables
  # ============================================================================

  defmodule BasicVars do
    use LiveStyle

    # StyleX: stylex.defineVars({ color: 'red', nextColor: 'green', otherColor: 'blue' })
    # Returns: { color: "var(--xwx8imx)", nextColor: "var(--xk6xtqk)", ... }
    css_vars(:colors,
      primary: "red",
      secondary: "blue",
      tertiary: "green"
    )
  end

  defmodule VarsWithMediaQuery do
    use LiveStyle

    # StyleX: otherColor: { default: 'blue', '@media (prefers-color-scheme: dark)': 'lightblue' }
    css_vars(:colors,
      background: %{
        default: "white",
        "@media (prefers-color-scheme: dark)": "black"
      }
    )
  end

  defmodule VarsWithNestedAtRules do
    use LiveStyle

    # StyleX test: "tokens object with nested @-rules"
    # Input:
    #   color: {
    #     default: 'blue',
    #     '@media (prefers-color-scheme: dark)': {
    #       default: 'lightblue',
    #       '@supports (color: oklab(0 0 0))': 'oklab(0.7 -0.3 -0.4)',
    #     }
    #   }
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

  # ============================================================================
  # Typed Variables (stylex.types equivalent)
  # ============================================================================

  defmodule TypedVars do
    use LiveStyle
    import LiveStyle.Types

    # StyleX test: "stylex.types used in tokens object"
    # Input:
    #   color: stylex.types.color({
    #     default: 'red',
    #     '@media (prefers-color-scheme: dark)': 'white',
    #     '@media print': 'black',
    #   })
    css_vars(:colors,
      primary:
        color(%{
          default: "red",
          "@media (prefers-color-scheme: dark)": "white",
          "@media print": "black"
        })
    )

    # Simple typed variable without conditionals
    css_vars(:animation,
      angle: angle("0deg"),
      duration: time("200ms")
    )
  end

  defmodule VarsUsedInRules do
    use LiveStyle

    css_vars(:theme,
      primary_color: "blue",
      text_size: "16px"
    )

    css_class(:styled,
      color: css_var({__MODULE__, :theme, :primary_color}),
      font_size: css_var({__MODULE__, :theme, :text_size})
    )
  end

  # ============================================================================
  # Themes (createTheme)
  # ============================================================================

  defmodule ThemeVars do
    use LiveStyle

    css_vars(:base,
      color: "red",
      bg: "white"
    )
  end

  defmodule DarkTheme do
    use LiveStyle

    css_theme({ThemeVars, :base}, :dark,
      color: "white",
      bg: "black"
    )
  end

  defmodule HighContrastTheme do
    use LiveStyle

    css_theme({ThemeVars, :base}, :high_contrast,
      color: "black",
      bg: "yellow"
    )
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "basic CSS variables" do
    test "variables are stored with css_name as var reference" do
      # StyleX: { color: "var(--xwx8imx)", ... }
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :primary})
      assert primary.css_name =~ ~r/^--[a-z0-9]+$/
      assert primary.value == "red"
    end

    test "variables have correct values stored" do
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :primary})

      secondary =
        LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :secondary})

      tertiary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :tertiary})

      assert primary.value == "red"
      assert secondary.value == "blue"
      assert tertiary.value == "green"
    end

    test "different variables have different hashed names" do
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :primary})

      secondary =
        LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :secondary})

      tertiary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :tertiary})

      names = [primary.css_name, secondary.css_name, tertiary.css_name]
      assert length(Enum.uniq(names)) == 3
    end
  end

  describe "CSS variables with media queries" do
    test "stores conditional values correctly" do
      background =
        LiveStyle.get_metadata(
          LiveStyle.VarsTest.VarsWithMediaQuery,
          {:var, :colors, :background}
        )

      # Should store the conditional value structure
      assert is_map(background.value)
      assert background.value.default == "white"
      assert background.value[:"@media (prefers-color-scheme: dark)"] == "black"
    end

    test "generates CSS with @media wrapper" do
      # StyleX output for @media conditional:
      # "@media (prefers-color-scheme: dark){:root{--xwx8imx:lightblue;}}"
      css = generate_css()

      # Should have default value in :root (no spaces - StyleX format)
      assert css =~ ~r/:root\{[^}]*--v[a-z0-9]+:white;/

      # Should have @media wrapped conditional (no spaces - StyleX format)
      assert css =~ ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*--v[a-z0-9]+:black;/
    end
  end

  describe "CSS variables with nested @-rules" do
    test "stores nested conditional values correctly" do
      color =
        LiveStyle.get_metadata(LiveStyle.VarsTest.VarsWithNestedAtRules, {:var, :colors, :color})

      # Should store the nested conditional value structure
      assert is_map(color.value)
      assert color.value.default == "blue"
      assert is_map(color.value[:"@media (prefers-color-scheme: dark)"])
      assert color.value[:"@media (prefers-color-scheme: dark)"].default == "lightblue"

      assert color.value[:"@media (prefers-color-scheme: dark)"][
               :"@supports (color: oklab(0 0 0))"
             ] ==
               "oklab(0.7 -0.3 -0.4)"
    end

    test "generates CSS with nested @-rule wrappers" do
      # StyleX output for nested @-rules:
      # 1. ":root{--xwx8imx:blue;}" - default
      # 2. "@media (prefers-color-scheme: dark){:root{--xwx8imx:lightblue;}}" - @media default
      # 3. "@supports ...{@media ...{:root{--xwx8imx:oklab(0.7 -0.3 -0.4);}}}"
      #    Note: @supports wraps @media (innermost at-rule becomes outermost wrapper)
      css = generate_css()

      color_var =
        LiveStyle.get_metadata(LiveStyle.VarsTest.VarsWithNestedAtRules, {:var, :colors, :color})

      var_name = color_var.css_name

      # Should have default value in :root (no spaces - StyleX format)
      assert css =~ ~r/:root\{[^}]*#{Regex.escape(var_name)}:blue;/

      # Should have @media wrapped value for dark mode default (no spaces - StyleX format)
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*#{Regex.escape(var_name)}:lightblue;/

      # Should have @supports wrapping @media for the nested value
      # StyleX nests as: @supports{@media{:root{...}}}
      assert css =~
               ~r/@supports \(color: oklab\(0 0 0\)\)\{@media \(prefers-color-scheme: dark\)\{:root\{[^}]*#{Regex.escape(var_name)}:oklab/
    end
  end

  describe "using CSS variables in rules" do
    test "css_var reference in css_class generates var() in atomic class" do
      # StyleX: ".xx2qnu0{color:var(--xwx8imx)}"
      rule = LiveStyle.get_metadata(LiveStyle.VarsTest.VarsUsedInRules, {:class, :styled})

      primary_var =
        LiveStyle.get_metadata(LiveStyle.VarsTest.VarsUsedInRules, {:var, :theme, :primary_color})

      text_var =
        LiveStyle.get_metadata(LiveStyle.VarsTest.VarsUsedInRules, {:var, :theme, :text_size})

      # Color should reference the variable
      color = rule.atomic_classes["color"]
      assert color.ltr =~ "var(#{primary_var.css_name})"

      # Font-size should reference the variable
      font_size = rule.atomic_classes["font-size"]
      assert font_size.ltr =~ "var(#{text_var.css_name})"
    end
  end

  describe "themes (css_theme)" do
    test "themes are stored in manifest" do
      dark_theme = LiveStyle.get_metadata(LiveStyle.VarsTest.DarkTheme, {:theme, :base, :dark})

      high_contrast =
        LiveStyle.get_metadata(
          LiveStyle.VarsTest.HighContrastTheme,
          {:theme, :base, :high_contrast}
        )

      # Should have themes stored
      assert dark_theme != nil
      assert high_contrast != nil
    end

    test "different themes have different class names" do
      dark_theme = LiveStyle.get_metadata(LiveStyle.VarsTest.DarkTheme, {:theme, :base, :dark})

      high_contrast =
        LiveStyle.get_metadata(
          LiveStyle.VarsTest.HighContrastTheme,
          {:theme, :base, :high_contrast}
        )

      assert dark_theme.css_name != high_contrast.css_name
    end

    test "themes override the correct variables" do
      dark_theme = LiveStyle.get_metadata(LiveStyle.VarsTest.DarkTheme, {:theme, :base, :dark})
      base_color = LiveStyle.get_metadata(LiveStyle.VarsTest.ThemeVars, {:var, :base, :color})
      base_bg = LiveStyle.get_metadata(LiveStyle.VarsTest.ThemeVars, {:var, :base, :bg})

      # Dark theme should have overrides for color and bg (using hashed var names as keys)
      assert dark_theme.overrides[base_color.css_name] == "white"
      assert dark_theme.overrides[base_bg.css_name] == "black"
    end
  end

  describe "variable naming" do
    test "variable names are hashed" do
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :primary})

      secondary =
        LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :secondary})

      tertiary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :tertiary})

      # All variable names should have the var prefix pattern
      assert primary.css_name =~ ~r/^--[a-z0-9]+$/
      assert secondary.css_name =~ ~r/^--[a-z0-9]+$/
      assert tertiary.css_name =~ ~r/^--[a-z0-9]+$/
    end
  end

  describe "variable priority" do
    # StyleX: variables have priority 0.1, @media overrides have 0.2
    # Note: We may not implement fractional priorities exactly the same way

    test "variables are stored in manifest" do
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.BasicVars, {:var, :colors, :primary})
      assert primary != nil
    end
  end

  describe "typed variables (stylex.types equivalent)" do
    test "typed variables store type information" do
      # StyleX: stylex.types.color() generates @property rule
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :colors, :primary})
      assert primary.type != nil
      assert primary.type.syntax == "<color>"
    end

    test "typed variables with conditionals store both type and values" do
      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :colors, :primary})
      assert primary.type.syntax == "<color>"
      assert is_map(primary.value)
      assert primary.value.default == "red"
      assert primary.value[:"@media (prefers-color-scheme: dark)"] == "white"
      assert primary.value[:"@media print"] == "black"
    end

    test "generates @property rule for typed variables" do
      # StyleX output:
      # "@property --xwx8imx { syntax: "<color>"; inherits: true; initial-value: red }"
      css = generate_css()

      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :colors, :primary})
      var_name = primary.css_name

      # Should have @property rule with correct syntax
      assert css =~ ~r/@property #{Regex.escape(var_name)}/
      assert css =~ ~r/syntax:.*<color>/
      assert css =~ ~r/initial-value:.*red/
    end

    test "generates @property rules for different types" do
      css = generate_css()

      angle_var = LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :animation, :angle})

      duration_var =
        LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :animation, :duration})

      # Angle variable
      assert css =~ ~r/@property #{Regex.escape(angle_var.css_name)}/
      assert css =~ ~r/syntax:.*<angle>/

      # Time variable
      assert css =~ ~r/@property #{Regex.escape(duration_var.css_name)}/
      assert css =~ ~r/syntax:.*<time>/
    end

    test "generates CSS variables with conditional values for typed vars" do
      css = generate_css()

      primary = LiveStyle.get_metadata(LiveStyle.VarsTest.TypedVars, {:var, :colors, :primary})
      var_name = primary.css_name

      # Default value in :root (no-space format: :root{--var:value;})
      assert css =~ ~r/:root\{[^}]*#{Regex.escape(var_name)}:red;/

      # @media dark mode override (no-space format)
      assert css =~
               ~r/@media \(prefers-color-scheme: dark\)\{:root\{[^}]*#{Regex.escape(var_name)}:white;/

      # @media print override (no-space format)
      assert css =~ ~r/@media print\{:root\{[^}]*#{Regex.escape(var_name)}:black;/
    end
  end
end
