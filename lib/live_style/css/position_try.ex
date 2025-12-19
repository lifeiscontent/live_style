defmodule LiveStyle.CSS.PositionTry do
  @moduledoc """
  Generates CSS `@position-try` rules from the manifest.

  This module handles generation of CSS Anchor Positioning `@position-try` rules,
  which define fallback positions for anchored elements.

  ## Supported Formats

  Entries can be in two formats:

  1. **New format** with LTR/RTL variants:
     ```
     %{ltr: "@position-try --top {...}", rtl: "@position-try --top {...}"}
     ```

  2. **Legacy format** from `css_position_try` macro:
     ```
     %{css_name: "--top", declarations: %{top: 0, left: "anchor(left)"}}
     ```
  """

  alias LiveStyle.Value

  @doc """
  Generates all @position-try CSS rules from the manifest.

  Returns a string containing all position-try rules, or an empty string
  if there are no position-try entries.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.position_try
    |> Enum.flat_map(fn {_key, entry} -> generate_entry(entry) end)
    |> Enum.join("\n")
  end

  # Generate CSS for a single position-try entry
  defp generate_entry(%{ltr: ltr_rule, rtl: nil}) do
    [ltr_rule]
  end

  defp generate_entry(%{ltr: ltr_rule, rtl: rtl_rule}) do
    # Note: RTL variants for @position-try are rare since logical
    # properties are handled by the browser. If present, we output both.
    [ltr_rule, rtl_rule]
  end

  # Legacy format with css_name and declarations (from css_position_try macro)
  defp generate_entry(%{css_name: css_name, declarations: declarations}) do
    generate_from_declarations(css_name, declarations)
  end

  # Generate position-try rules from declarations in minified format
  # Note: We keep logical properties as-is (browser handles RTL automatically)
  defp generate_from_declarations(css_name, declarations) do
    decl_str =
      declarations
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join("", fn {k, v} ->
        css_prop = Value.to_css_property(k)
        css_value = to_string(v)
        "#{css_prop}:#{css_value};"
      end)

    ["@position-try #{css_name}{#{decl_str}}"]
  end
end
