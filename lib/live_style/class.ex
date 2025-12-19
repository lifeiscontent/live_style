defmodule LiveStyle.Class do
  @moduledoc """
  Style class definition and lookup for LiveStyle.

  This is an internal module that handles the processing of `css_class/2` declarations.
  You typically don't use this module directly - instead use `LiveStyle.Sheet` with
  the `css_class/2` macro.

  ## Responsibilities

  - Defining static and dynamic style classes
  - Looking up class entries by module and name
  - Orchestrating declaration processing via specialized processors

  ## Internal API Example

      # Static class (called by css_class macro)
      LiveStyle.Class.define(MyModule, :button, %{display: "flex", padding: "8px"})

      # Dynamic class
      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])

      # Lookup
      LiveStyle.Class.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """

  alias LiveStyle.Class.ConditionalProcessor
  alias LiveStyle.Class.DynamicProcessor
  alias LiveStyle.Class.PseudoElementProcessor
  alias LiveStyle.Class.SimpleProcessor
  alias LiveStyle.{Include, Manifest}

  @doc """
  Defines a static style class.

  ## Parameters

    * `module` - The module defining the class
    * `name` - The class name (atom)
    * `declarations` - Map of CSS property declarations

  ## Example

      LiveStyle.Class.define(MyModule, :button, %{display: "flex"})
  """
  @spec define(module(), atom(), map()) :: :ok
  def define(module, name, declarations) do
    key = Manifest.simple_key(module, name)

    # Resolve __include__ entries first
    resolved_declarations = Include.resolve(declarations, module)

    # Process declarations into atomic classes
    {atomic_classes, class_string} = process_declarations(resolved_declarations)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: resolved_declarations,
      dynamic: false
    }

    # Only update if the entry has changed (or doesn't exist)
    # This avoids unnecessary writes during test parallel loading while
    # still updating when source code changes in development
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_class(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_class(manifest, key, entry)
      end
    end)

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
    {atomic_classes, class_string} = DynamicProcessor.process(all_props)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props,
      param_names: param_names,
      dynamic: true
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_class(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_class(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Looks up a class by module and name.

  Returns the class entry or raises if not found.

  ## Examples

      LiveStyle.Class.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """
  @spec lookup!(module(), atom()) :: map()
  def lookup!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      nil ->
        raise ArgumentError, """
        Unknown class: #{inspect(module)}.#{name}

        Make sure #{inspect(module)} is compiled before this module.
        """

      entry ->
        entry
    end
  end

  defp process_declarations(declarations) do
    # Separate into: simple values, conditional values, and pseudo-element declarations
    {pseudo_decls, rest} =
      Enum.split_with(declarations, fn {prop, _value} ->
        LiveStyle.Pseudo.element?(prop)
      end)

    {simple_decls, conditional_decls} =
      rest
      |> Enum.split_with(fn {_prop, value} ->
        not LiveStyle.Class.Conditional.conditional?(value)
      end)

    # Process each type of declaration via specialized processors
    simple_atomic = SimpleProcessor.process(simple_decls)
    conditional_atomic = ConditionalProcessor.process(conditional_decls)
    pseudo_atomic = PseudoElementProcessor.process(pseudo_decls)

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
end
