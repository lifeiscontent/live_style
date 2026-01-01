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
    |> Enum.sort_by(fn {_key, entry} -> entry.ident end)
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
  # Conditional values are sorted lists at this point (converted at storage time)
  defp collect_rules(overrides, conditions_path) do
    Enum.flat_map(overrides, fn {name, value} ->
      collect_value(name, value, conditions_path)
    end)
  end

  defp collect_value(name, value, conditions_path) when is_binary(value) do
    [{conditions_path, name, value}]
  end

  # Handle sorted lists (converted from maps at storage time)
  defp collect_value(name, value, conditions_path) when is_list(value) do
    if conditional_list?(value) do
      Enum.flat_map(value, &collect_list_entry(&1, name, conditions_path))
    else
      [{conditions_path, name, to_string(value)}]
    end
  end

  defp collect_value(name, value, conditions_path) do
    [{conditions_path, name, to_string(value)}]
  end

  defp collect_list_entry({key, inner_value}, name, conditions_path)
       when key in [:default, "default"] do
    if is_list(inner_value) and conditional_list?(inner_value) do
      collect_value(name, inner_value, conditions_path)
    else
      [{conditions_path, name, to_string(inner_value)}]
    end
  end

  defp collect_list_entry({condition, inner_value}, name, conditions_path) do
    condition_str = to_string(condition)

    if is_list(inner_value) and conditional_list?(inner_value) do
      collect_value(name, inner_value, conditions_path ++ [condition_str])
    else
      [{conditions_path ++ [condition_str], name, to_string(inner_value)}]
    end
  end

  # Check if a list is a conditional value list
  defp conditional_list?([{key, _} | _]) when is_atom(key) or is_binary(key), do: true
  defp conditional_list?(_), do: false
end
