defmodule LiveStyle.Runtime.RefResolver do
  @moduledoc """
  Resolves style references to property class lists.

  This module handles the lookup of style references across different formats:
  - Atom refs (local to module)
  - Module tuple refs (cross-module)
  - Dynamic refs (runtime values)

  ## Reference Types

  1. **Atom ref** - `:button` - looks up in the module's property_classes
  2. **Module tuple** - `{OtherModule, :button}` - looks up in another module
  3. **Dynamic ref** - `{:button, args}` - evaluates at runtime with args

  ## Return Values

  All resolve functions return a tagged tuple:
  - `{:static, prop_classes}` - Static class list
  - `{:dynamic, prop_classes, var_list}` - Dynamic with property classes and CSS variables
  - `:skip` - Reference should be skipped
  """

  @type prop_classes :: [{atom(), String.t() | :__unset__}]
  @type resolve_result ::
          {:static, prop_classes()}
          | {:dynamic, prop_classes(), list()}
          | :skip

  @doc """
  Resolves a reference to property classes.

  ## Parameters

    * `module` - The module context for resolution
    * `ref` - The reference to resolve
    * `property_classes_map` - The module's property classes lookup

  ## Returns

  A tagged tuple indicating the type of resolution result.
  """
  @spec resolve(module(), term(), keyword()) :: resolve_result()
  def resolve(_module, ref, property_classes) when is_atom(ref) do
    prop_classes = Keyword.get(property_classes, ref, [])
    {:static, prop_classes}
  end

  def resolve(_module, {other_module, name}, _property_classes)
      when is_atom(other_module) and is_atom(name) do
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Keyword.get(other_prop_classes, name, [])
        {:static, prop_classes}

      _ ->
        :skip
    end
  end

  # Cross-module dynamic class: {{OtherModule, :name}, args}
  def resolve(_module, {{other_module, name}, args}, _property_classes)
      when is_atom(other_module) and is_atom(name) do
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Keyword.get(other_prop_classes, name, [])

        dynamic_names = other_module.__live_style__(:dynamic_names)

        if name in dynamic_names do
          fn_name = :"__dynamic_#{name}__"
          var_list = apply(other_module, fn_name, [args])
          {:dynamic, prop_classes, var_list || []}
        else
          {:static, prop_classes}
        end

      _ ->
        :skip
    end
  end

  def resolve(module, {name, args}, property_classes) when is_atom(name) do
    dynamic_names = module.__live_style__(:dynamic_names)

    if name in dynamic_names do
      # Dynamic classes: get property_classes from compile-time map, compute var_list at runtime
      prop_classes = Keyword.get(property_classes, name, [])
      fn_name = :"__dynamic_#{name}__"
      var_list = apply(module, fn_name, [args])
      {:dynamic, prop_classes, var_list || []}
    else
      prop_classes = Keyword.get(property_classes, name, [])
      {:static, prop_classes}
    end
  end

  def resolve(_module, _ref, _property_classes), do: :skip
end
