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
  alias LiveStyle.Utils

  @doc """
  Defines CSS custom properties under a namespace.
  """
  @spec define(module(), atom(), map() | keyword()) :: :ok
  def define(module, namespace, vars) do
    vars = Utils.normalize_to_map(vars)

    Enum.each(vars, fn {name, value} ->
      key = Manifest.namespaced_key(module, namespace, name)
      define_var(module, namespace, name, key, value)
    end)

    :ok
  end

  defp define_var(module, namespace, name, key, value) do
    css_name = Hash.var_name(module, namespace, name)
    {css_value, type_info} = extract_var_value(value)

    entry = %{
      css_name: css_name,
      value: css_value,
      type: type_info
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_var(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_var(manifest, key, entry)
      end
    end)
  end

  @doc """
  Looks up a CSS variable by module/namespace/name.

  Returns the raw CSS custom property name (`--...`) or raises if not found.

  This matches the convention across LiveStyle where `lookup!/…` returns the
  concrete CSS "key" string.

  ## Examples

      name = LiveStyle.Vars.lookup!(MyTokens, :color, :primary)
      # => "--vabc123"
      "var(\#{name})"
      # => "var(--vabc123)"
  """
  @spec lookup!(module(), atom(), atom()) :: String.t()
  def lookup!(module, namespace, name) do
    %{css_name: css_name} = LiveStyle.Manifest.Access.var!(module, namespace, name)
    css_name
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
end
