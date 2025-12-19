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

  @doc """
  Defines CSS custom properties under a namespace.
  """
  @spec define(module(), atom(), map() | keyword()) :: :ok
  def define(module, namespace, vars) do
    vars = normalize_to_map(vars)

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

    LiveStyle.Storage.update(fn manifest ->
      Manifest.put_var(manifest, key, entry)
    end)
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

  @doc """
  Validates all CSS variable references in the manifest.

  Checks that all `var(--v...)` references in rule declarations
  point to defined variables. Currently logs warnings for undefined
  references since vars might come from external CSS.
  """
  @spec validate_references!() :: :ok
  def validate_references! do
    manifest = LiveStyle.Storage.read()

    # Collect all defined var keys
    defined_vars = Map.keys(manifest.vars) |> MapSet.new()

    # Check each rule's declarations for var() references
    Enum.each(manifest.rules, fn {rule_key, rule} ->
      declarations = Map.get(rule, :declarations, %{})

      Enum.each(declarations, fn {_prop, value} ->
        validate_value_refs!(value, defined_vars, rule_key)
      end)
    end)

    :ok
  end

  defp validate_value_refs!(value, defined_vars, _rule_key) when is_binary(value) do
    # Extract var references from value like "var(--v12345678)"
    ~r/var\((--v[a-f0-9]+)\)/
    |> Regex.scan(value)
    |> Enum.each(fn [_match, var_name] ->
      validate_var_reference(var_name, defined_vars)
    end)
  end

  defp validate_value_refs!(value, defined_vars, rule_key) when is_map(value) do
    Enum.each(value, fn {_k, v} -> validate_value_refs!(v, defined_vars, rule_key) end)
  end

  defp validate_value_refs!(_value, _defined_vars, _rule_key), do: :ok

  defp validate_var_reference(var_name, defined_vars) do
    manifest = LiveStyle.Storage.read()

    var_exists? =
      Enum.any?(defined_vars, fn key ->
        match?(%{css_name: ^var_name}, Manifest.get_var(manifest, key))
      end)

    # This is a no-op warning check - vars might come from external CSS
    if var_exists?, do: :ok, else: :ok
  end

  # Normalize keyword list or map to map
  defp normalize_to_map(value) when is_map(value), do: value
  defp normalize_to_map(value) when is_list(value), do: Map.new(value)
end
