defmodule LiveStyle.Runtime.RefResolver do
  @moduledoc """
  Resolves style references to property class maps.

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
  - `{:static, prop_classes}` - Static class map
  - `{:dynamic, class_string, var_map}` - Dynamic with CSS variables
  - `:skip` - Reference should be skipped
  """

  @type prop_classes :: %{atom() => String.t() | :__unset__}
  @type resolve_result ::
          {:static, prop_classes()}
          | {:dynamic, String.t(), map()}
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
  @spec resolve(module(), term(), map()) :: resolve_result()
  def resolve(_module, ref, property_classes_map) when is_atom(ref) do
    prop_classes = Map.get(property_classes_map, ref, %{})
    {:static, prop_classes}
  end

  def resolve(_module, {other_module, name}, _property_classes_map)
      when is_atom(other_module) and is_atom(name) do
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Map.get(other_prop_classes, name, %{})
        {:static, prop_classes}

      _ ->
        :skip
    end
  end

  def resolve(module, {name, args}, _property_classes_map) when is_atom(name) do
    dynamic_names = module.__live_style__(:dynamic_names)

    if name in dynamic_names do
      fn_name = :"__dynamic_#{name}__"
      {class_string, var_map} = apply(module, fn_name, [args])
      {:dynamic, class_string, var_map || %{}}
    else
      prop_classes = module.__live_style__(:property_classes) |> Map.get(name, %{})
      {:static, prop_classes}
    end
  end

  def resolve(_module, _ref, _property_classes_map), do: :skip
end
