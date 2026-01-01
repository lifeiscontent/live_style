defmodule LiveStyle.Compiler.CSS.PositionTry do
  @moduledoc """
  Generates CSS `@position-try` rules from the manifest.

  This module handles generation of CSS Anchor Positioning `@position-try` rules,
  which define fallback positions for anchored elements.

  ## Entry Format

  Entries from the `position_try` macro have the format:

      %{ident: "--xabc123", declarations: %{top: "0", left: "anchor(left)"}}

  """

  alias LiveStyle.Utils

  @doc """
  Generates all @position-try CSS rules from the manifest.

  Returns a string containing all position-try rules, or an empty string
  if there are no position-try entries.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.position_try
    |> Enum.sort_by(fn {_key, entry} -> entry.ident end)
    |> Enum.flat_map(fn {_key, entry} -> generate_entry(entry) end)
    |> Enum.join("\n")
  end

  defp generate_entry(%{ident: ident, declarations: declarations}) do
    decl_str = Utils.format_declarations(declarations)
    ["@position-try #{ident}{#{decl_str}}"]
  end
end
