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

  ## CSS Variable Overrides

  When a dynamic class overrides CSS variables defined via `vars()` (using property
  keys like `{var({Module, :name}), value}`), we do NOT generate `@property` rules
  for those. The original var definition controls inheritance, and we WANT these
  to inherit so child elements can see the overridden values.

  StyleX also distinguishes between:
  - Typed vars (from defineVars): `inherits: true`
  - Dynamic style vars: `inherits: false` (unless pseudo element)
  """

  alias LiveStyle.{Config, Manifest.ClassEntry}

  @doc """
  Generates @property rules for all dynamic CSS variables in the manifest.

  Returns a string containing all @property rules, or empty string if none.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    prefix = Config.class_name_prefix()

    manifest.classes
    |> Enum.filter(fn {_key, entry} -> ClassEntry.dynamic?(entry) end)
    |> Enum.flat_map(fn {_key, entry} ->
      Keyword.fetch!(entry, :atomic_classes)
      |> Enum.map(fn {_prop, data} -> Keyword.get(data, :var) end)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    # Skip CSS variable overrides - they should inherit to cascade to children
    # Var overrides use names like --xabc123 (from var({Module, :name}))
    # Regular dynamic vars use names like --x-opacity (prefix + property name)
    |> Enum.reject(&var_override?(&1, prefix))
    |> Enum.sort()
    |> Enum.map_join("\n", &format_property_rule/1)
  end

  # Detect if a CSS variable is a var override vs a regular dynamic var
  # Var overrides have the hashed name pattern: --{prefix} followed by alphanumeric only
  # Regular dynamic vars have: --{prefix}- followed by a property name (with hyphens)
  defp var_override?(css_var, prefix) do
    # Regular dynamic vars have pattern: --{prefix}-{property-name}
    # e.g., --x-opacity, --x-background-color
    regular_dynamic_prefix = "--#{prefix}-"

    # Var overrides have pattern: --{prefix}{hash} where hash is alphanumeric only
    # e.g., --xabc123, --x1v14wkz
    var_override_prefix = "--#{prefix}"

    cond do
      # Regular dynamic var - has prefix followed by hyphen then property name
      String.starts_with?(css_var, regular_dynamic_prefix) ->
        false

      # Var override - has prefix followed by alphanumeric hash (no hyphen)
      String.starts_with?(css_var, var_override_prefix) ->
        rest = String.slice(css_var, String.length(var_override_prefix)..-1//1)
        # Hashed names are alphanumeric only, no hyphens
        String.match?(rest, ~r/^[a-z0-9]+$/)

      true ->
        false
    end
  end

  defp format_property_rule(css_var) do
    "@property #{css_var} { syntax: \"*\"; inherits: false; }"
  end
end
