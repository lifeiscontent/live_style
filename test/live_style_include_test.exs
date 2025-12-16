defmodule LiveStyleIncludeTest do
  use ExUnit.Case, async: false

  setup do
    LiveStyle.clear()
    :ok
  end

  describe "__include__ key" do
    test "copies style properties from another module at compile time" do
      # Define a base styles module
      defmodule TestBaseStyles do
        use LiveStyle

        style(:button_base, %{
          display: "inline-flex",
          align_items: "center",
          padding: "8px 16px"
        })
      end

      # Define a module that includes the base styles
      defmodule TestButton do
        use LiveStyle

        style(:primary, %{
          __include__: [{TestBaseStyles, :button_base}],
          background_color: "blue",
          color: "white"
        })
      end

      # The resulting style should have all properties
      style = TestButton.__live_style__(:primary)

      assert style[:display] == "inline-flex"
      assert style[:align_items] == "center"
      assert style[:padding] == "8px 16px"
      assert style[:background_color] == "blue"
      assert style[:color] == "white"
    end

    test "later properties override included properties" do
      defmodule TestOverrideBase do
        use LiveStyle

        style(:base, %{
          padding: "8px",
          color: "black"
        })
      end

      defmodule TestOverrideChild do
        use LiveStyle

        style(:child, %{
          __include__: [{TestOverrideBase, :base}],
          padding: "16px"
        })
      end

      style = TestOverrideChild.__live_style__(:child)

      # padding should be overridden
      assert style[:padding] == "16px"
      # color should be inherited
      assert style[:color] == "black"
    end

    test "multiple includes are merged in order" do
      defmodule TestMultiBase1 do
        use LiveStyle

        style(:layout, %{
          display: "flex",
          flex_direction: "column"
        })
      end

      defmodule TestMultiBase2 do
        use LiveStyle

        style(:spacing, %{
          padding: "16px",
          margin: "8px"
        })
      end

      defmodule TestMultiChild do
        use LiveStyle

        style(:combined, %{
          __include__: [
            {TestMultiBase1, :layout},
            {TestMultiBase2, :spacing}
          ],
          gap: "4px"
        })
      end

      style = TestMultiChild.__live_style__(:combined)

      assert style[:display] == "flex"
      assert style[:flex_direction] == "column"
      assert style[:padding] == "16px"
      assert style[:margin] == "8px"
      assert style[:gap] == "4px"
    end

    test "generates correct CSS for included styles" do
      defmodule TestCSSBase do
        use LiveStyle

        style(:card_base, %{
          border_radius: "8px",
          box_shadow: "0 2px 4px rgba(0,0,0,0.1)"
        })
      end

      defmodule TestCSSChild do
        use LiveStyle

        style(:elevated_card, %{
          __include__: [{TestCSSBase, :card_base}],
          background_color: "white"
        })
      end

      # Generate CSS
      css = LiveStyle.get_all_css()

      # Should contain all properties
      assert css =~ "border-radius: 8px"
      assert css =~ "box-shadow: 0 2px 4px rgba(0,0,0,0.1)"
      assert css =~ "background-color: white"
    end

    test "included styles with pseudo-classes work correctly" do
      defmodule TestPseudoBase do
        use LiveStyle

        style(:interactive, %{
          cursor: "pointer",
          transition: "all 0.2s ease"
        })
      end

      defmodule TestPseudoChild do
        use LiveStyle

        style(:button, %{
          __include__: [{TestPseudoBase, :interactive}],
          background_color: %{
            default: "gray",
            ":hover": "blue"
          }
        })
      end

      style = TestPseudoChild.__live_style__(:button)

      assert style[:cursor] == "pointer"
      assert style[:transition] == "all 0.2s ease"
      assert style[:background_color] == %{default: "gray", ":hover": "blue"}
    end

    test "raises error when including non-existent style" do
      defmodule TestErrorBase do
        use LiveStyle

        style(:exists, %{display: "flex"})
      end

      assert_raise CompileError, ~r/Style :nonexistent not found/, fn ->
        defmodule TestErrorChild do
          use LiveStyle

          style(:broken, %{
            __include__: [{TestErrorBase, :nonexistent}],
            color: "red"
          })
        end
      end
    end

    test "raises error when including from module without LiveStyle" do
      defmodule TestPlainModule do
        def hello, do: "world"
      end

      assert_raise CompileError, ~r/Cannot include styles from/, fn ->
        defmodule TestBrokenInclude do
          use LiveStyle

          style(:broken, %{
            __include__: [{TestPlainModule, :something}],
            color: "red"
          })
        end
      end
    end

    test "__include__ key is not present in final style" do
      defmodule TestNoIncludeKey do
        use LiveStyle

        style(:base, %{display: "flex"})
      end

      defmodule TestNoIncludeKeyChild do
        use LiveStyle

        style(:child, %{
          __include__: [{TestNoIncludeKey, :base}],
          color: "red"
        })
      end

      style = TestNoIncludeKeyChild.__live_style__(:child)

      refute Map.has_key?(style, :__include__)
      assert style[:display] == "flex"
      assert style[:color] == "red"
    end

    test "later includes override earlier includes" do
      defmodule TestIncludeOrder1 do
        use LiveStyle

        style(:first, %{
          color: "red",
          padding: "8px"
        })
      end

      defmodule TestIncludeOrder2 do
        use LiveStyle

        style(:second, %{
          color: "blue",
          margin: "4px"
        })
      end

      defmodule TestIncludeOrderChild do
        use LiveStyle

        style(:merged, %{
          __include__: [
            {TestIncludeOrder1, :first},
            {TestIncludeOrder2, :second}
          ]
        })
      end

      style = TestIncludeOrderChild.__live_style__(:merged)

      # color should be "blue" from second include
      assert style[:color] == "blue"
      # padding should be from first include
      assert style[:padding] == "8px"
      # margin should be from second include
      assert style[:margin] == "4px"
    end
  end

  describe "self-reference includes" do
    test "can include a style from the same module" do
      defmodule TestSelfRefBasic do
        use LiveStyle

        style(:base, %{
          display: "flex",
          padding: "8px"
        })

        style(:extended, %{
          __include__: [:base],
          color: "blue"
        })
      end

      style = TestSelfRefBasic.__live_style__(:extended)

      assert style[:display] == "flex"
      assert style[:padding] == "8px"
      assert style[:color] == "blue"
    end

    test "self-reference overrides work correctly" do
      defmodule TestSelfRefOverride do
        use LiveStyle

        style(:base, %{
          padding: "8px",
          margin: "4px"
        })

        style(:large, %{
          __include__: [:base],
          padding: "16px"
        })
      end

      style = TestSelfRefOverride.__live_style__(:large)

      # padding should be overridden
      assert style[:padding] == "16px"
      # margin should be inherited
      assert style[:margin] == "4px"
    end

    test "can chain self-references" do
      defmodule TestSelfRefChain do
        use LiveStyle

        style(:base, %{
          display: "flex",
          cursor: "pointer"
        })

        style(:button, %{
          __include__: [:base],
          padding: "8px 16px",
          border_radius: "4px"
        })

        style(:primary_button, %{
          __include__: [:button],
          background_color: "blue",
          color: "white"
        })
      end

      style = TestSelfRefChain.__live_style__(:primary_button)

      # From :base
      assert style[:display] == "flex"
      assert style[:cursor] == "pointer"
      # From :button
      assert style[:padding] == "8px 16px"
      assert style[:border_radius] == "4px"
      # From :primary_button
      assert style[:background_color] == "blue"
      assert style[:color] == "white"
    end

    test "can mix self-references and external includes" do
      defmodule TestMixedExternal do
        use LiveStyle

        style(:external_base, %{
          transition: "all 0.2s ease"
        })
      end

      defmodule TestMixedSelf do
        use LiveStyle

        style(:local_base, %{
          display: "flex",
          padding: "8px"
        })

        style(:combined, %{
          __include__: [
            {TestMixedExternal, :external_base},
            :local_base
          ],
          color: "red"
        })
      end

      style = TestMixedSelf.__live_style__(:combined)

      # From external module
      assert style[:transition] == "all 0.2s ease"
      # From local self-reference
      assert style[:display] == "flex"
      assert style[:padding] == "8px"
      # From local style
      assert style[:color] == "red"
    end

    test "raises error when self-referencing undefined style" do
      assert_raise CompileError, ~r/Cannot include :nonexistent/, fn ->
        defmodule TestSelfRefError do
          use LiveStyle

          style(:broken, %{
            __include__: [:nonexistent],
            color: "red"
          })
        end
      end
    end

    test "raises error when self-referencing style defined later" do
      assert_raise CompileError, ~r/Cannot include :later/, fn ->
        defmodule TestSelfRefOrderError do
          use LiveStyle

          # Trying to include a style that's defined below
          style(:first, %{
            __include__: [:later],
            color: "red"
          })

          style(:later, %{
            padding: "8px"
          })
        end
      end
    end

    test "self-reference includes resolve nested includes" do
      defmodule TestSelfRefNested do
        use LiveStyle

        style(:level1, %{
          display: "flex"
        })

        style(:level2, %{
          __include__: [:level1],
          padding: "8px"
        })

        style(:level3, %{
          __include__: [:level2],
          color: "blue"
        })
      end

      style = TestSelfRefNested.__live_style__(:level3)

      # All levels should be merged
      assert style[:display] == "flex"
      assert style[:padding] == "8px"
      assert style[:color] == "blue"
    end
  end
end
