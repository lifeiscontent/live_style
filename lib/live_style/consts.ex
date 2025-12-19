defmodule LiveStyle.Consts do
  @moduledoc """
  Compile-time constants support for LiveStyle.

  Constants are values defined at compile time that can be referenced
  in style rules. Unlike CSS variables, constants don't generate any
  CSS output - they're purely for code organization and reuse.

  ## Example

      css_consts :breakpoint,
        sm: "@media (max-width: 640px)",
        lg: "@media (min-width: 1025px)"

      css_consts :z,
        modal: "50",
        tooltip: "100"

      # Reference in classes
      css_class :responsive,
        css_const({:breakpoint, :sm}) => [display: "none"]
  """

  alias LiveStyle.Manifest

  @doc """
  Defines compile-time constants under a namespace.
  """
  @spec define(module(), atom(), map() | keyword()) :: :ok
  def define(module, namespace, consts) do
    consts = normalize_to_map(consts)

    # In test environment, skip if const already exists to avoid race conditions
    if Mix.env() == :test do
      manifest = LiveStyle.Storage.read()

      Enum.each(consts, fn {name, value} ->
        key = Manifest.namespaced_key(module, namespace, name)

        unless Manifest.get_const(manifest, key) do
          define_const(key, value)
        end
      end)
    else
      Enum.each(consts, fn {name, value} ->
        key = Manifest.namespaced_key(module, namespace, name)
        define_const(key, value)
      end)
    end

    :ok
  end

  defp define_const(key, value) do
    LiveStyle.Storage.update(fn manifest ->
      Manifest.put_const(manifest, key, value)
    end)
  end

  @doc """
  Looks up a constant value by module, namespace, and name.

  Returns the value or raises if not found.

  ## Examples

      LiveStyle.Consts.lookup!(MyTokens, :breakpoint, :lg)
      # => "@media (min-width: 1025px)"
  """
  @spec lookup!(module(), atom(), atom()) :: term()
  def lookup!(module, namespace, name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_const(manifest, key) do
      nil ->
        raise ArgumentError, """
        Unknown constant: #{inspect(module)}.#{namespace}.#{name}

        Make sure #{inspect(module)} is compiled before this module.
        """

      value ->
        value
    end
  end

  # Normalize keyword list or map to map
  defp normalize_to_map(value) when is_map(value), do: value
  defp normalize_to_map(value) when is_list(value), do: Map.new(value)
end
