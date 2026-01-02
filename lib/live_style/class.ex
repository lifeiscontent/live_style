defmodule LiveStyle.Class do
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
      LiveStyle.Class.define(MyModule, :button, [display: "flex", padding: "8px"])

      # Dynamic class
      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity])

      # Fetch
      LiveStyle.Class.fetch!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: [...], ...}
  """

  alias LiveStyle.Class.{Conditional, DeclarationMerger}
  alias LiveStyle.Class.Include
  alias LiveStyle.Class.Processor
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
    * `declarations` - Keyword list of CSS property declarations
    * `opts` - Options including `:file` and `:line` for validation warnings

  ## Example

      LiveStyle.Class.define(MyModule, :button, [display: "flex"])
  """
  @spec define(module(), atom(), keyword(), keyword()) :: :ok
  def define(module, name, declarations, opts \\ []) do
    key = Manifest.key(module, name)

    # Resolve __include__ entries first
    resolved_declarations = Include.resolve(declarations, module)

    # Process declarations into atomic classes
    {atomic_classes, class_string} = process_declarations(resolved_declarations, opts)

    entry = [
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: resolved_declarations
    ]

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

  ## Example

      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity])
  """
  @spec define_dynamic(module(), atom(), [atom()]) :: :ok
  def define_dynamic(module, name, all_props) do
    key = Manifest.key(module, name)

    # For dynamic rules, generate CSS classes that use var(--x-prop) references
    # The actual values are set at runtime via inline styles
    {atomic_classes, class_string} = Processor.Dynamic.transform(all_props)

    entry = [
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props
    ]

    store_entry(key, entry)
    :ok
  end

  @doc """
  Defines a static style class directly in a manifest (for batch operations).

  This is used by `@before_compile` to batch all class definitions in a single
  manifest update, reducing lock contention during compilation.

  Returns the updated manifest.
  """
  @spec batch_define(Manifest.t(), module(), atom(), keyword(), keyword()) :: Manifest.t()
  def batch_define(manifest, module, name, declarations, opts \\ []) do
    key = Manifest.key(module, name)

    # Resolve __include__ entries first, using the in-progress manifest
    # so we can reference classes defined earlier in the same module
    resolved_declarations = Include.resolve(declarations, module, manifest)

    # Process declarations into atomic classes
    {atomic_classes, class_string} = process_declarations(resolved_declarations, opts)

    entry = [
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: resolved_declarations
    ]

    # Only update if different
    case Manifest.get_class(manifest, key) do
      ^entry -> manifest
      _ -> Manifest.put_class(manifest, key, entry)
    end
  end

  @doc """
  Defines a dynamic style class directly in a manifest (for batch operations).

  This is used by `@before_compile` to batch all class definitions in a single
  manifest update, reducing lock contention during compilation.

  Returns the updated manifest.
  """
  @spec batch_define_dynamic(Manifest.t(), module(), atom(), [atom()]) :: Manifest.t()
  def batch_define_dynamic(manifest, module, name, all_props) do
    key = Manifest.key(module, name)

    # For dynamic rules, generate CSS classes that use var(--x-prop) references
    # The actual values are set at runtime via inline styles
    {atomic_classes, class_string} = Processor.Dynamic.transform(all_props)

    entry = [
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props
    ]

    # Only update if different
    case Manifest.get_class(manifest, key) do
      ^entry -> manifest
      _ -> Manifest.put_class(manifest, key, entry)
    end
  end

  # LiveStyle follows modern StyleX syntax.
  #
  # Conditional selectors like pseudo-classes and at-rules must be nested inside
  # individual property values (e.g. `color: [default: ..., ":hover": ...]`).
  # Top-level conditional blocks are considered legacy contextual styles and are rejected.

  defp process_declarations(declarations, opts) do
    # Sort conditional values once before processing for deterministic iteration
    alias LiveStyle.Utils

    sorted_declarations =
      Enum.map(declarations, fn {k, v} -> {k, Utils.sort_conditional_value(v)} end)

    transformed_declarations =
      sorted_declarations
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
    simple_atomic = Processor.Simple.transform(simple_decls, opts)
    conditional_atomic = Processor.Conditional.transform(conditional_decls, opts)
    pseudo_atomic = Processor.PseudoElement.transform(pseudo_decls, opts)

    # Merge all atomic classes (lists merged with last-wins semantics)
    atomic =
      simple_atomic
      |> Utils.merge_declarations(conditional_atomic)
      |> Utils.merge_declarations(pseudo_atomic)

    class_string =
      atomic
      |> Enum.flat_map(&extract_class_names/1)
      |> Enum.join(" ")

    {atomic, class_string}
  end

  defp extract_class_names({_prop, entry}) when is_list(entry) do
    case Keyword.get(entry, :classes) do
      nil -> [Keyword.get(entry, :class)]
      classes -> Enum.map(classes, fn {_cond, e} -> Keyword.get(e, :class) end)
    end
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
    Enum.reduce(declarations, [], fn {prop, value}, acc ->
      prop_str = to_string(prop)

      if nested_condition_key?(prop_str) and map_or_kw?(value) do
        raise ArgumentError, legacy_condition_error(prop_str)
      else
        merge_property_value(acc, prop, value)
      end
    end)
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

  defp map_or_kw?(value) when is_list(value), do: Keyword.keyword?(value)
  defp map_or_kw?(_), do: false

  defp merge_property_value(acc, prop, value) do
    DeclarationMerger.merge(acc, prop, value)
  end
end
