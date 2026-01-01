defmodule LiveStyle.Vars do
  @moduledoc """
  CSS custom properties (variables) support.

  This module handles:
  - CSS custom properties (variables) defined with `vars`
  - Typed variables with `@property` rules for animation support

  For compile-time constants, see `LiveStyle.Consts`.

  ## Examples

      defmodule MyApp.Tokens do
        use LiveStyle

        vars primary: "#3b82f6",
             secondary: "#8b5cf6",
             spacing_sm: "8px"
      end

      # Reference in another module
      defmodule MyApp.Components do
        use LiveStyle

        class :button,
          color: var({MyApp.Tokens, :primary}),
          padding: var({MyApp.Tokens, :spacing_sm})
      end
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest
  alias LiveStyle.Utils

  use LiveStyle.Registry,
    entity_name: "CSS variable",
    manifest_type: :var,
    ref_field: :ident

  # Content-based CSS name generation (private)
  # Hashes module + name for identity-based naming
  defp ident(module, name) do
    input = "var:#{inspect(module)}.#{name}"
    "--v" <> Hash.create_hash(input)
  end

  @doc """
  Defines CSS custom properties.

  Called internally by the `vars` macro.
  """
  @spec define(module(), map() | keyword()) :: :ok
  def define(module, vars) do
    vars = Utils.normalize_to_map(vars)

    Enum.each(vars, fn {name, value} ->
      key = Manifest.simple_key(module, name)
      define_var(module, name, key, value)
    end)

    :ok
  end

  defp define_var(module, name, key, value) do
    ident = ident(module, name)
    {css_value, type_info} = extract_var_value(value)

    entry = %{
      ident: ident,
      value: css_value,
      type: type_info
    }

    store_entry(key, entry)
  end

  @doc """
  Gets the CSS variable reference wrapped in `var()` for use in style definitions.

  This is a convenience function equivalent to `"var(\#{ref(name)})"`.

  ## Examples

      class :themed,
        color: Vars.var({MyApp.Tokens, :primary})
        # => "var(--vabc123)"

      # Within the defining module:
      class :themed,
        color: Vars.var(:primary)
        # => "var(--vabc123)"
  """
  @spec var(atom() | {module(), atom()}) :: String.t()
  def var(name) when is_atom(name), do: var({__MODULE__, name})

  def var({module, name}) do
    "var(#{ref({module, name})})"
  end

  # Extract value and type info from a variable definition
  defp extract_var_value(%{__css_type__: type, value: value}) do
    syntax = "<#{type}>"
    {value, %{syntax: syntax, initial: value}}
  end

  # LiveStyle.TypedProperty format: %{syntax: "<angle>", initial: "0deg", inherits: true}
  defp extract_var_value(%{syntax: syntax, initial: initial} = typed)
       when is_binary(syntax) do
    inherits = Map.get(typed, :inherits, true)
    {initial, %{syntax: syntax, initial: initial, inherits: inherits}}
  end

  # LiveStyle.PropertyType module format: %{__type__: :typed_var, syntax: "<angle>", value: "0deg"}
  defp extract_var_value(%{__type__: :typed_var, syntax: syntax, value: value} = typed) do
    inherits = Map.get(typed, :inherits, true)
    {value, %{syntax: syntax, initial: value, inherits: inherits}}
  end

  defp extract_var_value(value) when is_binary(value) do
    {value, nil}
  end

  defp extract_var_value(value)
       when is_map(value) and not is_map_key(value, :__css_type__) and
              not is_map_key(value, :__type__) and not is_map_key(value, :syntax) do
    {value, nil}
  end

  defp extract_var_value(value) when is_number(value) do
    {to_string(value), nil}
  end
end
