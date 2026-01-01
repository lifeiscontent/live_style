defmodule LiveStyle.Compiler.Class do
  @moduledoc """
  Style class definition and lookup for LiveStyle.

  This is an internal module that handles the processing of `class/2` declarations.
  You typically don't use this module directly - instead use `LiveStyle` with
  the `class/2` macro.

  ## Responsibilities

  - Defining static and dynamic style classes
  - Looking up class entries by module and name
  - Orchestrating declaration processing via specialized processors

  ## Internal API Example

      # Static class (called by class macro)
      LiveStyle.Compiler.Class.define(MyModule, :button, %{display: "flex", padding: "8px"})

      # Dynamic class
      LiveStyle.Compiler.Class.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])

      # Lookup
      LiveStyle.Compiler.Class.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """

  alias LiveStyle.Compiler.Class.{Conditional, DeclarationMerger}
  alias LiveStyle.Compiler.Class.Include
  alias LiveStyle.Compiler.Class.Processor
  alias LiveStyle.Manifest

  use LiveStyle.Registry,
    entity_name: "Class",
    manifest_type: :class,
    ref_field: :class_string

  @doc """
  Defines a static style class.

  ## Parameters

    * `module` - The module defining the class
    * `name` - The class name (atom)
    * `declarations` - Map of CSS property declarations
    * `opts` - Options including `:file` and `:line` for validation warnings

  ## Example

      LiveStyle.Class.define(MyModule, :button, %{display: "flex"})
  """
  @spec define(module(), atom(), map(), keyword()) :: :ok
  def define(module, name, declarations, opts \\ []) do
    key = Manifest.simple_key(module, name)

    # Resolve __include__ entries first
    resolved_declarations = Include.resolve(declarations, module)

    # Process declarations into atomic classes
    {atomic_classes, class_string} = process_declarations(resolved_declarations, opts)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: resolved_declarations,
      dynamic: false
    }

    store_entry(key, entry)
    :ok
  end

  @doc """
  Defines a dynamic style class.

  Dynamic classes use CSS variables that are set at runtime via inline styles.

  ## Parameters

    * `module` - The module defining the class
    * `name` - The class name (atom)
    * `all_props` - List of all CSS properties in the class
    * `param_names` - List of parameter names for the dynamic function

  ## Example

      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])
  """
  @spec define_dynamic(module(), atom(), [atom()], [atom()]) :: :ok
  def define_dynamic(module, name, all_props, param_names) do
    key = Manifest.simple_key(module, name)

    # For dynamic rules, generate CSS classes that use var(--x-prop) references
    # The actual values are set at runtime via inline styles
    {atomic_classes, class_string} = Processor.Dynamic.process(all_props)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props,
      param_names: param_names,
      dynamic: true
    }

    store_entry(key, entry)
    :ok
  end

  # LiveStyle follows modern StyleX syntax.
  #
  # Conditional selectors like pseudo-classes and at-rules must be nested inside
  # individual property values (e.g. `color: [default: ..., ":hover": ...]`).
  # Top-level conditional blocks like `%{"@media (...)" => %{...}}` are considered
  # legacy contextual styles and are rejected.

  defp process_declarations(declarations, opts) do
    transformed_declarations =
      declarations
      |> Enum.to_list()
      |> expand_nested_condition_blocks()

    # Separate into: simple values, conditional values, and pseudo-element declarations
    {pseudo_decls, rest} =
      Enum.split_with(transformed_declarations, fn {prop, _value} ->
        LiveStyle.Pseudo.element?(prop)
      end)

    {simple_decls, conditional_decls} =
      rest
      |> Enum.split_with(fn {_prop, value} ->
        not Conditional.conditional?(value)
      end)

    # Process each type of declaration via specialized processors
    simple_atomic = Processor.Simple.process(simple_decls, opts)
    conditional_atomic = Processor.Conditional.process(conditional_decls, opts)
    pseudo_atomic = Processor.PseudoElement.process(pseudo_decls, opts)

    # Merge all atomic classes
    atomic =
      simple_atomic
      |> Map.merge(conditional_atomic)
      |> Map.merge(pseudo_atomic)

    class_string =
      atomic
      |> Map.values()
      |> Enum.flat_map(fn
        %{class: class} -> [class]
        %{classes: classes} -> Enum.map(Map.values(classes), & &1.class)
      end)
      |> Enum.join(" ")

    {atomic, class_string}
  end

  defp expand_nested_condition_blocks(declarations) do
    {pseudo, rest} =
      Enum.split_with(declarations, fn {prop, _value} ->
        LiveStyle.Pseudo.element?(prop)
      end)

    expanded = expand_declarations(rest)
    pseudo ++ expanded
  end

  defp expand_declarations(declarations) do
    declarations
    |> Enum.reduce(%{}, fn {prop, value}, acc ->
      prop_str = to_string(prop)

      if nested_condition_key?(prop_str) and map_or_kw?(value) do
        raise ArgumentError, legacy_condition_error(prop_str)
      else
        merge_property_value(acc, prop, value)
      end
    end)
    |> Enum.to_list()
  end

  defp legacy_condition_error("@" <> _rest) do
    "Legacy at-rule object syntax is not supported. " <>
      "Nest at-rules under properties instead (e.g. color: [default: ..., \"@media (...)\": ...])."
  end

  defp legacy_condition_error(<<":", _rest::binary>>) do
    "Legacy pseudo-class object syntax is not supported. " <>
      "Nest pseudo-classes under properties instead (e.g. color: [default: ..., \":hover\": ...])."
  end

  defp nested_condition_key?("::" <> _rest), do: false
  defp nested_condition_key?(<<":", _rest::binary>>), do: true
  defp nested_condition_key?(<<"@", _rest::binary>>), do: true
  defp nested_condition_key?(_), do: false

  defp map_or_kw?(value) when is_map(value), do: true
  defp map_or_kw?(value) when is_list(value), do: Keyword.keyword?(value)
  defp map_or_kw?(_), do: false

  defp merge_property_value(acc, prop, value) do
    DeclarationMerger.merge(acc, prop, value)
  end
end
