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
    if live_style_module?(other_module) do
      other_prop_classes = other_module.__live_style__(:property_classes)
      prop_classes = Keyword.get(other_prop_classes, name, [])
      {:static, prop_classes}
    else
      :skip
    end
  end

  # Cross-module dynamic class: {{OtherModule, :name}, args}
  def resolve(_module, {{other_module, name}, args}, _property_classes)
      when is_atom(other_module) and is_atom(name) do
    if live_style_module?(other_module) do
      other_prop_classes = other_module.__live_style__(:property_classes)
      prop_classes = Keyword.get(other_prop_classes, name, [])
      dynamic_names = other_module.__live_style__(:dynamic_names)
      resolve_dynamic(other_module, name, args, prop_classes, dynamic_names)
    else
      :skip
    end
  end

  def resolve(module, {name, args}, property_classes) when is_atom(name) do
    if function_exported?(module, :__live_style__, 1) do
      dynamic_names = module.__live_style__(:dynamic_names)
      prop_classes = Keyword.get(property_classes, name, [])
      resolve_dynamic(module, name, args, prop_classes, dynamic_names)
    else
      :skip
    end
  end

  def resolve(_module, _ref, _property_classes), do: :skip

  defp resolve_dynamic(module, name, args, prop_classes, dynamic_names) do
    if name in dynamic_names do
      fn_name = :"__dynamic_#{name}__"

      if function_exported?(module, fn_name, 1) do
        var_list = apply(module, fn_name, [args])
        {:dynamic, prop_classes, var_list || []}
      else
        {:static, prop_classes}
      end
    else
      {:static, prop_classes}
    end
  end

  defp live_style_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__live_style__, 1)
  end
end
