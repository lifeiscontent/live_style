defmodule LiveStyleTokensTest do
  use ExUnit.Case, async: false

  setup do
    LiveStyle.clear()
    :ok
  end

  describe "defvars/2 macro" do
    test "defines CSS custom properties" do
      defmodule TestDefvars do
        use LiveStyle.Tokens

        defvars(:color, %{
          primary: "#1e68fa",
          secondary: "#6b7280"
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ ":root {"
      assert css =~ "#1e68fa"
      assert css =~ "#6b7280"
    end

    test "generates hashed variable names" do
      defmodule TestVarNames do
        use LiveStyle.Tokens

        defvars(:fill, %{
          primary: "blue"
        })
      end

      css = LiveStyle.get_all_css()

      # Variable names should be hashed like --v1234567
      assert css =~ ~r/--v[a-f0-9]+: blue/
    end

    test "var() references resolve to same hash" do
      defmodule TestVarRef do
        use LiveStyle.Tokens

        defvars(:text, %{
          primary: "#000000"
        })
      end

      defmodule TestVarRefStyle do
        use LiveStyle

        style(:test, %{
          color: var(:text_primary)
        })
      end

      css = LiveStyle.get_all_css()

      # Extract the var name from :root
      [_, var_name] = Regex.run(~r/(--v[a-f0-9]+): #000000/, css)

      # The style should reference the same var
      assert css =~ "var(#{var_name})"
    end
  end

  describe "typed variables with LiveStyle.Types" do
    test "generates @property rules for typed vars" do
      defmodule TestTypedVars do
        use LiveStyle.Tokens
        import LiveStyle.Types

        defvars(:anim, %{
          rotation: angle("0deg"),
          progress: percentage("0%")
        })
      end

      css = LiveStyle.get_all_css()

      # Should have @property rules
      assert css =~ "@property"
      assert css =~ "syntax: '<angle>'"
      assert css =~ "syntax: '<percentage>'"
      assert css =~ "inherits: true"
    end

    test "color type generates correct @property syntax" do
      defmodule TestColorType do
        use LiveStyle.Tokens
        import LiveStyle.Types

        defvars(:theme, %{
          accent: color("#ff0000")
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "syntax: '<color>'"
      assert css =~ "#ff0000"
    end

    test "length type generates correct @property syntax" do
      defmodule TestLengthType do
        use LiveStyle.Tokens

        defvars(:space, %{
          gap: LiveStyle.Types.length("16px")
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "syntax: '<length>'"
      assert css =~ "16px"
    end
  end

  describe "defconsts/2 macro" do
    test "defines compile-time constants" do
      defmodule TestConsts do
        use LiveStyle.Tokens

        defconsts(:breakpoints, %{
          sm: "@media (max-width: 640px)",
          lg: "@media (min-width: 1024px)"
        })
      end

      # Constants should be accessible as functions
      assert TestConsts.breakpoints_sm() == "@media (max-width: 640px)"
      assert TestConsts.breakpoints_lg() == "@media (min-width: 1024px)"

      # Also accessible as a map
      assert TestConsts.breakpoints()[:sm] == "@media (max-width: 640px)"
    end

    test "constants can be used in style conditions" do
      defmodule TestConstsInStyle do
        use LiveStyle.Tokens

        defconsts(:bp, %{
          md: "@media (min-width: 768px)"
        })
      end

      defmodule TestConstsStyleUsage do
        use LiveStyle

        style(:responsive, %{
          padding: %{
            TestConstsInStyle.bp_md() => "16px",
            default: "8px"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "@media (min-width: 768px)"
      assert css =~ "padding: 16px"
    end
  end

  describe "create_theme/3 macro" do
    test "creates a theme class that overrides variables" do
      defmodule TestThemeBase do
        use LiveStyle.Tokens

        defvars(:fill, %{
          background: "#ffffff",
          surface: "#f5f5f5"
        })

        create_theme(:dark, :fill, %{
          background: "#1a1a1a",
          surface: "#2d2d2d"
        })
      end

      # Should generate a function returning the theme class
      theme_class = TestThemeBase.dark()
      assert is_binary(theme_class)
      assert theme_class =~ ~r/^t[a-f0-9]+$/

      css = LiveStyle.get_all_css()

      # Should have the theme rule
      assert css =~ ".#{theme_class}"
      assert css =~ "#1a1a1a"
      assert css =~ "#2d2d2d"
    end

    test "theme overrides use same variable names as base" do
      defmodule TestThemeVarNames do
        use LiveStyle.Tokens

        defvars(:color, %{
          text: "#000000"
        })

        create_theme(:inverted, :color, %{
          text: "#ffffff"
        })
      end

      css = LiveStyle.get_all_css()

      # Extract the var name from :root
      [_, var_name] = Regex.run(~r/(--v[a-f0-9]+): #000000/, css)

      # Theme should override the same var
      assert css =~ ~r/\.t[a-f0-9]+ \{ #{Regex.escape(var_name)}: #ffffff/
    end
  end

  describe "var reference validation" do
    test "records var usages for validation" do
      defmodule TestVarUsage do
        use LiveStyle

        style(:test, %{
          color: var(:text_primary)
        })
      end

      manifest = LiveStyle.read_manifest()
      usages = manifest[:var_usages] || %{}

      # Should have recorded the usage
      assert map_size(usages) > 0
    end
  end
end
