defmodule LiveStyle.Compiler.CSS.DynamicProperties do
  @moduledoc """
  Generates @property rules for dynamic CSS variables.

  Dynamic classes use CSS variables that are set at runtime via inline styles.
  To prevent these variables from being inherited by pseudo-elements (which can
  cause unexpected behavior), we generate @property rules with `inherits: false`.

  This matches StyleX's behavior where dynamic styles generate:

      @property --x-opacity { syntax: "*"; inherits: false; }

  ## Why `inherits: false`?

  Without this, a pseudo-element like `::before` would inherit the CSS variable
  value from its parent, which may not be the intended behavior for dynamic styles.
  Setting `inherits: false` ensures each element must explicitly set the variable.
  """

  alias LiveStyle.Manifest.ClassEntry

  @doc """
  Generates @property rules for all dynamic CSS variables in the manifest.

  Returns a string containing all @property rules, or empty string if none.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.classes
    |> Enum.filter(fn {_key, entry} -> ClassEntry.dynamic?(entry) end)
    |> Enum.flat_map(fn {_key, entry} ->
      Keyword.fetch!(entry, :atomic_classes)
      |> Enum.map(fn {_prop, data} -> Keyword.get(data, :var) end)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&format_property_rule/1)
    |> Enum.join("\n")
  end

  defp format_property_rule(css_var) do
    "@property #{css_var} { syntax: \"*\"; inherits: false; }"
  end
end
