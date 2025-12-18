defmodule LiveStyle.TypesTest do
  @moduledoc """
  Tests for CSS variable types (stylex.types equivalent).

  These tests mirror StyleX's stylex-types-test.js to ensure LiveStyle handles
  typed CSS variables the same way StyleX does.

  StyleX Reference:
  - packages/@stylexjs/babel-plugin/src/shared/types/index.js
  - packages/@stylexjs/babel-plugin/src/shared/types/__tests__/stylex-types-test.js
  - packages/@stylexjs/babel-plugin/__tests__/transform-stylex-defineVars-test.js
  """
  use LiveStyle.TestCase, async: true

  alias LiveStyle.Types

  # ============================================================================
  # Type Helper Function Tests
  # ============================================================================

  describe "angle/1" do
    test "creates typed value with correct syntax" do
      result = Types.angle("45deg")
      assert result.syntax == "<angle>"
      assert result.value == "45deg"
      assert result.__type__ == :typed_var
    end

    test "works with different angle units" do
      assert Types.angle("0deg").value == "0deg"
      assert Types.angle("90deg").value == "90deg"
      assert Types.angle("0.5turn").value == "0.5turn"
      assert Types.angle("3.14159rad").value == "3.14159rad"
    end

    test "works with conditional values" do
      result = Types.angle(%{default: "0deg", "@media (min-width: 768px)": "45deg"})
      assert result.syntax == "<angle>"
      assert result.value.default == "0deg"
      assert result.value[:"@media (min-width: 768px)"] == "45deg"
    end
  end

  describe "color/1" do
    test "creates typed value with correct syntax" do
      result = Types.color("red")
      assert result.syntax == "<color>"
      assert result.value == "red"
      assert result.__type__ == :typed_var
    end

    test "works with different color formats" do
      assert Types.color("#ff0000").value == "#ff0000"
      assert Types.color("rgb(255, 0, 0)").value == "rgb(255, 0, 0)"
      assert Types.color("hsl(0, 100%, 50%)").value == "hsl(0, 100%, 50%)"
      assert Types.color("oklch(0.7 0.15 30)").value == "oklch(0.7 0.15 30)"
    end

    test "works with conditional values" do
      result =
        Types.color(%{
          default: "red",
          "@media (prefers-color-scheme: dark)": "white",
          "@media print": "black"
        })

      assert result.syntax == "<color>"
      assert result.value.default == "red"
      assert result.value[:"@media (prefers-color-scheme: dark)"] == "white"
      assert result.value[:"@media print"] == "black"
    end
  end

  describe "url/1" do
    test "creates typed value with correct syntax" do
      result = Types.url("url(#image)")
      assert result.syntax == "<url>"
      assert result.value == "url(#image)"
      assert result.__type__ == :typed_var
    end

    test "works with different url formats" do
      assert Types.url("url(https://example.com/image.png)").value ==
               "url(https://example.com/image.png)"

      assert Types.url("url(data:image/png;base64,abc)").value == "url(data:image/png;base64,abc)"
    end
  end

  describe "image/1" do
    test "creates typed value with correct syntax" do
      result = Types.image("url(#image)")
      assert result.syntax == "<image>"
      assert result.value == "url(#image)"
      assert result.__type__ == :typed_var
    end

    test "works with gradient values" do
      assert Types.image("linear-gradient(red, blue)").value == "linear-gradient(red, blue)"

      assert Types.image("radial-gradient(circle, red, blue)").value ==
               "radial-gradient(circle, red, blue)"
    end
  end

  describe "integer/1" do
    test "creates typed value with correct syntax from integer" do
      result = Types.integer(3)
      assert result.syntax == "<integer>"
      assert result.value == "3"
      assert result.__type__ == :typed_var
    end

    test "creates typed value with correct syntax from string" do
      result = Types.integer("5")
      assert result.syntax == "<integer>"
      assert result.value == "5"
    end

    test "converts integer to string" do
      # StyleX behavior: Integer.create(1) -> obj.value === "1"
      assert Types.integer(1).value == "1"
      assert Types.integer(0).value == "0"
      assert Types.integer(-5).value == "-5"
    end
  end

  describe "length/1" do
    test "creates typed value with correct syntax" do
      result = Types.length("1px")
      assert result.syntax == "<length>"
      assert result.value == "1px"
      assert result.__type__ == :typed_var
    end

    test "works with different length units" do
      assert Types.length("4px").value == "4px"
      assert Types.length("1rem").value == "1rem"
      assert Types.length("1em").value == "1em"
      assert Types.length("10vh").value == "10vh"
      assert Types.length("50vw").value == "50vw"
    end

    test "works with conditional values" do
      result = Types.length(%{default: "8px", "@media (min-width: 768px)": "16px"})
      assert result.syntax == "<length>"
      assert result.value.default == "8px"
      assert result.value[:"@media (min-width: 768px)"] == "16px"
    end
  end

  describe "length_percentage/1" do
    test "creates typed value with correct syntax" do
      result = Types.length_percentage("50%")
      assert result.syntax == "<length-percentage>"
      assert result.value == "50%"
      assert result.__type__ == :typed_var
    end

    test "works with both length and percentage values" do
      assert Types.length_percentage("100px").value == "100px"
      assert Types.length_percentage("50%").value == "50%"
      assert Types.length_percentage("calc(100% - 20px)").value == "calc(100% - 20px)"
    end
  end

  describe "percentage/1" do
    test "creates typed value with correct syntax" do
      result = Types.percentage("50%")
      assert result.syntax == "<percentage>"
      assert result.value == "50%"
      assert result.__type__ == :typed_var
    end

    test "works with different percentage values" do
      assert Types.percentage("0%").value == "0%"
      assert Types.percentage("100%").value == "100%"
      assert Types.percentage("33.33%").value == "33.33%"
    end
  end

  describe "number/1" do
    test "creates typed value with correct syntax from number" do
      result = Types.number(1.5)
      assert result.syntax == "<number>"
      assert result.value == "1.5"
      assert result.__type__ == :typed_var
    end

    test "creates typed value with correct syntax from string" do
      result = Types.number("0.5")
      assert result.syntax == "<number>"
      assert result.value == "0.5"
    end

    test "converts number to string" do
      # StyleX behavior: Num.create(1) -> obj.value === "1"
      assert Types.number(1).value == "1"
      assert Types.number(0.5).value == "0.5"
      assert Types.number(0).value == "0"
    end
  end

  describe "resolution/1" do
    test "creates typed value with correct syntax" do
      result = Types.resolution("96dpi")
      assert result.syntax == "<resolution>"
      assert result.value == "96dpi"
      assert result.__type__ == :typed_var
    end

    test "works with different resolution units" do
      assert Types.resolution("96dpi").value == "96dpi"
      assert Types.resolution("2dppx").value == "2dppx"
      assert Types.resolution("300dpcm").value == "300dpcm"
    end
  end

  describe "time/1" do
    test "creates typed value with correct syntax" do
      result = Types.time("1s")
      assert result.syntax == "<time>"
      assert result.value == "1s"
      assert result.__type__ == :typed_var
    end

    test "works with different time units" do
      assert Types.time("0.5s").value == "0.5s"
      assert Types.time("300ms").value == "300ms"
      assert Types.time("0s").value == "0s"
    end
  end

  describe "transform_function/1" do
    test "creates typed value with correct syntax" do
      result = Types.transform_function("translateX(10px)")
      assert result.syntax == "<transform-function>"
      assert result.value == "translateX(10px)"
      assert result.__type__ == :typed_var
    end

    test "works with different transform functions" do
      assert Types.transform_function("rotate(45deg)").value == "rotate(45deg)"
      assert Types.transform_function("scale(1.5)").value == "scale(1.5)"
      assert Types.transform_function("skewX(10deg)").value == "skewX(10deg)"
    end
  end

  describe "transform_list/1" do
    test "creates typed value with correct syntax" do
      result = Types.transform_list("translateX(10px) rotate(45deg)")
      assert result.syntax == "<transform-list>"
      assert result.value == "translateX(10px) rotate(45deg)"
      assert result.__type__ == :typed_var
    end

    test "works with multiple transforms" do
      value = "translateX(10px) rotate(45deg) scale(1.5)"
      assert Types.transform_list(value).value == value
    end
  end

  # ============================================================================
  # Helper Function Tests
  # ============================================================================

  describe "typed?/1" do
    test "returns true for typed values" do
      assert Types.typed?(Types.color("red")) == true
      assert Types.typed?(Types.length("10px")) == true
      assert Types.typed?(Types.angle("45deg")) == true
    end

    test "returns false for non-typed values" do
      assert Types.typed?("red") == false
      assert Types.typed?(10) == false
      assert Types.typed?(%{}) == false
      assert Types.typed?(nil) == false
    end
  end

  describe "initial_value/1" do
    test "extracts string value" do
      assert Types.initial_value(Types.color("red")) == "red"
      assert Types.initial_value(Types.length("10px")) == "10px"
    end

    test "extracts default from conditional value" do
      typed = Types.color(%{default: "red", "@media print": "black"})
      assert Types.initial_value(typed) == "red"
    end

    test "converts integer to string" do
      typed = Types.integer(3)
      assert Types.initial_value(typed) == "3"
    end

    test "converts float to string" do
      typed = Types.number(1.5)
      assert Types.initial_value(typed) == "1.5"
    end
  end

  describe "unwrap_value/1" do
    test "returns the inner value" do
      assert Types.unwrap_value(Types.color("red")) == "red"
      assert Types.unwrap_value(Types.length("10px")) == "10px"
    end

    test "returns map for conditional values" do
      typed = Types.color(%{default: "red", "@media print": "black"})
      assert Types.unwrap_value(typed) == %{default: "red", "@media print": "black"}
    end
  end

  describe "typed_var/3" do
    test "creates typed value from atom syntax" do
      result = Types.typed_var(:color, "blue")
      assert result.syntax == "<color>"
      assert result.value == "blue"
    end

    test "creates typed value from string syntax" do
      result = Types.typed_var("<color>#", "red, blue, green")
      assert result.syntax == "<color>#"
      assert result.value == "red, blue, green"
    end

    test "supports inherits option" do
      result = Types.typed_var(:length, "1rem", true)
      assert result.inherits == true
    end

    test "converts all atom shortcuts correctly" do
      assert Types.typed_var(:color, "v").syntax == "<color>"
      assert Types.typed_var(:length, "v").syntax == "<length>"
      assert Types.typed_var(:angle, "v").syntax == "<angle>"
      assert Types.typed_var(:integer, "v").syntax == "<integer>"
      assert Types.typed_var(:number, "v").syntax == "<number>"
      assert Types.typed_var(:time, "v").syntax == "<time>"
      assert Types.typed_var(:percentage, "v").syntax == "<percentage>"
      assert Types.typed_var(:url, "v").syntax == "<url>"
      assert Types.typed_var(:image, "v").syntax == "<image>"
      assert Types.typed_var(:resolution, "v").syntax == "<resolution>"
      assert Types.typed_var(:length_percentage, "v").syntax == "<length-percentage>"
      assert Types.typed_var(:transform_function, "v").syntax == "<transform-function>"
      assert Types.typed_var(:transform_list, "v").syntax == "<transform-list>"
    end

    test "handles unknown atom by wrapping in angle brackets" do
      result = Types.typed_var(:custom_type, "value")
      assert result.syntax == "<custom_type>"
    end
  end

  # ============================================================================
  # CSS Variables Integration Tests
  # ============================================================================

  defmodule AllTypedVars do
    use LiveStyle
    # Don't import length/1 to avoid conflict with Kernel.length/1
    import LiveStyle.Types, except: [length: 1]
    alias LiveStyle.Types

    # Test all type helpers with css_vars
    css_vars(:all_types,
      angle_var: angle("45deg"),
      color_var: color("red"),
      url_var: url("url(#image)"),
      image_var: image("linear-gradient(red, blue)"),
      integer_var: integer(3),
      length_var: Types.length("10px"),
      length_percentage_var: length_percentage("50%"),
      percentage_var: percentage("100%"),
      number_var: number(1.5),
      resolution_var: resolution("96dpi"),
      time_var: time("200ms"),
      transform_function_var: transform_function("rotate(45deg)"),
      transform_list_var: transform_list("translateX(10px) rotate(45deg)")
    )
  end

  defmodule TypedVarsWithConditions do
    use LiveStyle
    # Don't import length/1 to avoid conflict with Kernel.length/1
    import LiveStyle.Types, except: [length: 1]
    alias LiveStyle.Types

    # StyleX test: "stylex.types used in tokens object"
    css_vars(:themed,
      primary_color:
        color(%{
          default: "red",
          "@media (prefers-color-scheme: dark)": "white",
          "@media print": "black"
        }),
      spacing:
        Types.length(%{
          default: "8px",
          "@media (min-width: 768px)": "16px"
        })
    )
  end

  describe "typed variables in css_vars" do
    test "all types store correct type information" do
      manifest = get_manifest()

      # Angle
      angle_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.angle_var"]
      assert angle_var.type.syntax == "<angle>"
      assert angle_var.value == "45deg"

      # Color
      color_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.color_var"]
      assert color_var.type.syntax == "<color>"
      assert color_var.value == "red"

      # URL
      url_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.url_var"]
      assert url_var.type.syntax == "<url>"
      assert url_var.value == "url(#image)"

      # Image
      image_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.image_var"]
      assert image_var.type.syntax == "<image>"
      assert image_var.value == "linear-gradient(red, blue)"

      # Integer
      integer_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.integer_var"]
      assert integer_var.type.syntax == "<integer>"
      assert integer_var.value == "3"

      # Length
      length_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.length_var"]
      assert length_var.type.syntax == "<length>"
      assert length_var.value == "10px"

      # Length-Percentage
      lp_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.length_percentage_var"]
      assert lp_var.type.syntax == "<length-percentage>"
      assert lp_var.value == "50%"

      # Percentage
      percentage_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.percentage_var"]
      assert percentage_var.type.syntax == "<percentage>"
      assert percentage_var.value == "100%"

      # Number
      number_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.number_var"]
      assert number_var.type.syntax == "<number>"
      assert number_var.value == "1.5"

      # Resolution
      resolution_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.resolution_var"]
      assert resolution_var.type.syntax == "<resolution>"
      assert resolution_var.value == "96dpi"

      # Time
      time_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.time_var"]
      assert time_var.type.syntax == "<time>"
      assert time_var.value == "200ms"

      # Transform Function
      tf_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.transform_function_var"]
      assert tf_var.type.syntax == "<transform-function>"
      assert tf_var.value == "rotate(45deg)"

      # Transform List
      tl_var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.transform_list_var"]
      assert tl_var.type.syntax == "<transform-list>"
      assert tl_var.value == "translateX(10px) rotate(45deg)"
    end

    test "typed variables with conditionals store both type and values" do
      manifest = get_manifest()

      primary = manifest.vars["LiveStyle.TypesTest.TypedVarsWithConditions.themed.primary_color"]
      assert primary.type.syntax == "<color>"
      assert is_map(primary.value)
      assert primary.value.default == "red"
      assert primary.value[:"@media (prefers-color-scheme: dark)"] == "white"
      assert primary.value[:"@media print"] == "black"

      spacing = manifest.vars["LiveStyle.TypesTest.TypedVarsWithConditions.themed.spacing"]
      assert spacing.type.syntax == "<length>"
      assert is_map(spacing.value)
      assert spacing.value.default == "8px"
      assert spacing.value[:"@media (min-width: 768px)"] == "16px"
    end
  end

  describe "@property rule generation" do
    test "generates @property rule for typed variables" do
      # StyleX output:
      # "@property --xwx8imx { syntax: "<color>"; inherits: true; initial-value: red }"
      css = generate_css()

      color_var = get_manifest().vars["LiveStyle.TypesTest.AllTypedVars.all_types.color_var"]

      # Should have @property rule with correct syntax
      assert css =~ ~r/@property #{Regex.escape(color_var.css_name)}/
      assert css =~ ~r/syntax:.*<color>/
      assert css =~ ~r/initial-value:.*red/
    end

    test "generates @property rules for all types" do
      css = generate_css()
      manifest = get_manifest()

      # Check each type generates correct @property rule
      type_checks = [
        {"angle_var", "<angle>", "45deg"},
        {"color_var", "<color>", "red"},
        {"url_var", "<url>", "url\\(#image\\)"},
        {"image_var", "<image>", "linear-gradient"},
        {"integer_var", "<integer>", "3"},
        {"length_var", "<length>", "10px"},
        {"length_percentage_var", "<length-percentage>", "50%"},
        {"percentage_var", "<percentage>", "100%"},
        {"number_var", "<number>", "1.5"},
        {"resolution_var", "<resolution>", "96dpi"},
        {"time_var", "<time>", "200ms"},
        {"transform_function_var", "<transform-function>", "rotate"},
        {"transform_list_var", "<transform-list>", "translateX"}
      ]

      for {var_name, syntax, value_pattern} <- type_checks do
        var = manifest.vars["LiveStyle.TypesTest.AllTypedVars.all_types.#{var_name}"]

        assert css =~ ~r/@property #{Regex.escape(var.css_name)}/,
               "Missing @property for #{var_name}"

        assert css =~ ~r/syntax:.*#{Regex.escape(syntax)}/,
               "Missing syntax for #{var_name}"

        assert css =~ ~r/initial-value:.*#{value_pattern}/,
               "Missing initial-value for #{var_name}"
      end
    end

    test "generates CSS variables with conditional values for typed vars" do
      css = generate_css()

      primary =
        get_manifest().vars["LiveStyle.TypesTest.TypedVarsWithConditions.themed.primary_color"]

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
