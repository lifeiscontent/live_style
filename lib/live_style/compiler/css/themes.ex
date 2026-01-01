defmodule LiveStyle.Compiler.CSS.Themes do
  @moduledoc """
  CSS theme override generation for LiveStyle.

  This module handles generating theme override rules from the manifest.
  Themes allow overriding CSS variable values when a theme class is applied.

  ## Output Format

  Theme rules use high-specificity selectors to override variable values:

      .t12345,.t12345:root{--v67890:blue;}

  Conditional theme values are wrapped in at-rules:

      @media (prefers-color-scheme: dark){.t12345,.t12345:root{--v67890:darkblue;}}
  """

  alias LiveStyle.Manifest

  @doc """
  Generate theme CSS from manifest.
  """
  @spec generate(Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.themes
    |> Enum.flat_map(fn {_key, entry} ->
      %{ident: ident, overrides: overrides} = entry

      # Collect all rules: default, single-level conditional, and nested conditional
      # Each rule is {conditions_list, name, value} where conditions_list is a list of @-rule strings
      rules = collect_rules(overrides, [])

      # Group rules by their condition path
      grouped =
        rules
        |> Enum.group_by(fn {conditions, _name, _value} -> conditions end)

      # Generate CSS for each condition group
      grouped
      |> Enum.sort_by(fn {conditions, _} -> {length(conditions), conditions} end)
      |> Enum.map(fn {conditions, vars_list} ->
        generate_condition_css(ident, conditions, vars_list)
      end)
    end)
    |> Enum.join("\n")
  end

  defp generate_condition_css(ident, conditions, vars_list) do
    declarations =
      vars_list
      |> Enum.sort_by(fn {_, name, _} -> name end)
      |> Enum.map_join("", fn {_, name, value} -> "#{name}:#{value};" end)

    selector = ".#{ident},.#{ident}:root"
    inner = "#{selector}{#{declarations}}"

    wrap_with_conditions(inner, conditions)
  end

  defp wrap_with_conditions(inner, []), do: inner

  defp wrap_with_conditions(inner, conditions) do
    Enum.reduce(Enum.reverse(conditions), inner, fn condition, acc ->
      "#{condition}{#{acc}}"
    end)
  end

  # Recursively collect theme rules, tracking the condition path
  defp collect_rules(overrides, conditions_path) do
    Enum.flat_map(overrides, fn {name, value} ->
      collect_value(name, value, conditions_path)
    end)
  end

  defp collect_value(name, value, conditions_path) when is_map(value) do
    # Handle map values with :default and @-rule keys
    Enum.flat_map(value, fn
      {key, inner_value} when key in [:default, "default"] ->
        # Default value at this level
        if is_map(inner_value) do
          # Nested default (unusual but possible)
          collect_value(name, inner_value, conditions_path)
        else
          [{conditions_path, name, to_string(inner_value)}]
        end

      {condition, inner_value} ->
        # Conditional value - add to condition path
        condition_str = to_string(condition)

        if is_map(inner_value) do
          # Nested conditionals
          collect_value(name, inner_value, conditions_path ++ [condition_str])
        else
          [{conditions_path ++ [condition_str], name, to_string(inner_value)}]
        end
    end)
  end

  defp collect_value(name, value, conditions_path) when is_binary(value) do
    [{conditions_path, name, value}]
  end

  defp collect_value(name, value, conditions_path) do
    [{conditions_path, name, to_string(value)}]
  end
end
