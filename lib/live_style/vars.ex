defmodule LiveStyle.Vars do
  @moduledoc """
  CSS custom properties (variables) support.

  This module handles:
  - CSS custom properties (variables) defined with `css_vars`
  - Typed variables with `@property` rules for animation support

  For compile-time constants, see `LiveStyle.Consts`.
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest

  # ===========================================================================
  # CSS Variables (css_vars)
  # ===========================================================================

  @doc """
  Defines CSS custom properties under a namespace.
  """
  @spec define(module(), atom(), map() | keyword()) :: :ok
  def define(module, namespace, vars) do
    vars = normalize_to_map(vars)

    Enum.each(vars, fn {name, value} ->
      css_name = Hash.var_name(module, namespace, name)
      key = Manifest.namespaced_key(module, namespace, name)

      {css_value, type_info} = extract_var_value(value)

      entry = %{
        css_name: css_name,
        value: css_value,
        type: type_info
      }

      LiveStyle.Storage.update(fn manifest ->
        Manifest.put_var(manifest, key, entry)
      end)
    end)

    :ok
  end

  @doc """
  Looks up a CSS variable and returns a var() reference string.

  Raises if the variable is not found.

  ## Examples

      LiveStyle.Vars.lookup!(MyTokens, :color, :primary)
      # => "var(--xabc123)"
  """
  @spec lookup!(module(), atom(), atom()) :: String.t()
  def lookup!(module, namespace, name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_var(manifest, key) do
      nil ->
        raise ArgumentError, """
        Unknown CSS variable: #{inspect(module)}.#{namespace}.#{name}

        Make sure #{inspect(module)} is compiled before this module.
        """

      %{css_name: css_name} ->
        "var(#{css_name})"
    end
  end

  # Extract value and type info from a variable definition
  defp extract_var_value(%{__css_type__: type, value: value}) do
    syntax = "<#{type}>"
    {value, %{syntax: syntax, initial: value}}
  end

  # LiveStyle.Types module format: %{__type__: :typed_var, syntax: "<angle>", value: "0deg"}
  defp extract_var_value(%{__type__: :typed_var, syntax: syntax, value: value} = typed) do
    # Default to inherits: true for CSS custom properties
    inherits = Map.get(typed, :inherits, true)
    {value, %{syntax: syntax, initial: value, inherits: inherits}}
  end

  defp extract_var_value(value) when is_binary(value) do
    {value, nil}
  end

  defp extract_var_value(value)
       when is_map(value) and not is_map_key(value, :__css_type__) and
              not is_map_key(value, :__type__) do
    {value, nil}
  end

  defp extract_var_value(value) when is_number(value) do
    {to_string(value), nil}
  end

  # Normalize keyword list or map to map
  defp normalize_to_map(value) when is_map(value), do: value
  defp normalize_to_map(value) when is_list(value), do: Map.new(value)
end
