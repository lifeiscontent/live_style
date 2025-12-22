defmodule LiveStyle.CSS.Vars do
  @moduledoc """
  CSS custom property (variable) generation for LiveStyle.

  This module handles generating CSS output for:
  - @property rules (for typed CSS variables)
  - CSS custom property declarations in :root

  ## @property Rules

  Typed variables get `@property` rules for animation support:

      @property --color { syntax: "<color>"; inherits: true; initial-value: blue }

  ## CSS Variable Rules

  Variables are grouped by their at-rule conditions:

      :root{--v12345:blue;--v67890:red;}
      @media (prefers-color-scheme: dark){:root{--v12345:lightblue;}}

  ## StyleX Compatibility

  Output follows StyleX's minified format:
  - No spaces around colons or semicolons
  - No newlines between declarations
  """

  alias LiveStyle.Manifest

  @doc """
  Generate @property rules for typed CSS variables.

  Returns a string of @property rules, one per line.
  """
  @spec generate_properties(Manifest.t()) :: String.t()
  def generate_properties(manifest) do
    manifest.vars
    |> Enum.filter(fn {_key, entry} -> entry.type != nil end)
    |> Enum.map_join("\n", fn {_key, entry} ->
      %{css_name: css_name, type: type_info} = entry
      %{syntax: syntax, initial: initial} = type_info
      inherits = Map.get(type_info, :inherits, true)

      # Extract default value for @property initial-value
      initial_value = extract_initial_value(initial)

      # StyleX format: @property --var { syntax: "<type>"; inherits: true; initial-value: value }
      "@property #{css_name} { syntax: \"#{syntax}\"; inherits: #{inherits}; initial-value: #{initial_value} }"
    end)
  end

  @doc """
  Generate CSS custom property declarations.

  Groups variables by their at-rule conditions and generates :root blocks.
  """
  @spec generate_vars(Manifest.t()) :: String.t()
  def generate_vars(manifest) do
    vars = manifest.vars

    if map_size(vars) == 0 do
      ""
    else
      # Collect all CSS variable rules with their at-rule wrappers
      var_rules =
        vars
        |> Enum.flat_map(fn {_key, entry} ->
          %{css_name: css_name, value: value} = entry
          flatten_var_value(css_name, value, [])
        end)

      # Group by at-rules to create CSS blocks
      grouped =
        var_rules
        |> Enum.group_by(fn {at_rules, _name, _val} -> at_rules end)

      # Generate CSS for each group
      grouped
      |> Enum.sort_by(fn {at_rules, _} -> length(at_rules) end)
      |> Enum.map_join("\n", &generate_var_group_css/1)
    end
  end

  # Generate CSS for a group of variables sharing the same at-rule conditions
  alias LiveStyle.CSS.AtRules

  defp generate_var_group_css({at_rules, vars_list}) do
    declarations =
      vars_list
      |> Enum.sort_by(fn {_, name, _} -> name end)
      |> Enum.map_join("", fn {_, name, value} -> "#{name}:#{value};" end)

    # Build the CSS rule with :root selector (no spaces - StyleX format)
    inner = ":root{#{declarations}}"

    # Wrap with at-rules (no spaces - StyleX format)
    AtRules.wrap(at_rules, inner)
  end

  # Flatten a variable value into a list of {at_rules, css_name, value} tuples
  # Handles nested conditional values
  defp flatten_var_value(css_name, value, at_rules) when is_map(value) do
    Enum.flat_map(value, fn {key, val} ->
      flatten_var_entry(css_name, key, val, at_rules)
    end)
  end

  defp flatten_var_value(css_name, value, at_rules) when is_binary(value) do
    [{at_rules, css_name, value}]
  end

  defp flatten_var_value(css_name, value, at_rules) do
    [{at_rules, css_name, to_string(value)}]
  end

  # Handle default key with simple value
  defp flatten_var_entry(css_name, key, val, at_rules)
       when key in [:default, "default"] and (is_binary(val) or is_number(val)) do
    [{at_rules, css_name, to_string(val)}]
  end

  # Handle default key with nested map
  defp flatten_var_entry(css_name, key, val, at_rules) when key in [:default, "default"] do
    flatten_var_value(css_name, val, at_rules)
  end

  # Handle at-rule conditions
  defp flatten_var_entry(css_name, key, val, at_rules) do
    key_str = to_string(key)
    flatten_var_value(css_name, val, at_rules ++ [key_str])
  end

  # Extract the initial value for @property rules
  defp extract_initial_value(value) when is_binary(value), do: value
  defp extract_initial_value(value) when is_number(value), do: to_string(value)

  defp extract_initial_value(%{} = map) do
    # Check for :default or "default" key
    default = Map.get(map, :default) || Map.get(map, "default")

    case default do
      nil -> map |> Map.values() |> List.first() |> to_string()
      val when is_binary(val) -> val
      val -> to_string(val)
    end
  end

  defp extract_initial_value(value), do: to_string(value)
end
