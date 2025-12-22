defmodule LiveStyle.Runtime.Attrs do
  @moduledoc false

  alias LiveStyle.Value

  @spec resolve_attrs(module(), list(), keyword() | nil) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, opts) when is_atom(module) and is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    {merged_props, var_styles} =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce({%{}, []}, fn ref, {props_acc, vars_acc} ->
        resolve_ref_with_props(module, ref, property_classes_map)
        |> merge_resolved_ref(props_acc, vars_acc)
      end)

    class_string =
      merged_props
      |> Map.values()
      |> Enum.reject(&(&1 == :__unset__ or &1 == nil or &1 == ""))
      |> Enum.uniq()
      |> Enum.join(" ")

    extra_styles = extract_extra_styles(opts)
    style_string = build_style_string(var_styles, extra_styles)

    %LiveStyle.Attrs{class: class_string, style: style_string}
  end

  defp extract_extra_styles(nil), do: nil
  defp extract_extra_styles([]), do: nil

  defp extract_extra_styles(opts) when is_list(opts) do
    case Keyword.get(opts, :style) do
      nil -> nil
      styles when is_list(styles) -> format_extra_styles(styles)
      styles when is_map(styles) -> format_extra_styles(styles)
    end
  end

  defp format_extra_styles(styles) when is_list(styles) or is_map(styles) do
    Enum.map_join(styles, "; ", fn {key, value} ->
      css_prop = format_style_key(key)
      "#{css_prop}: #{value}"
    end)
  end

  defp format_style_key(key) when is_atom(key), do: Value.to_css_property(key)
  defp format_style_key(key) when is_binary(key), do: key

  defp build_style_string([], nil), do: nil
  defp build_style_string([], extra) when is_binary(extra), do: extra

  defp build_style_string(var_styles, nil) do
    var_styles
    |> Enum.reverse()
    |> Enum.reduce(%{}, &Map.merge(&2, &1))
    |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)
  end

  defp build_style_string(var_styles, extra) when is_binary(extra) do
    var_string =
      var_styles
      |> Enum.reverse()
      |> Enum.reduce(%{}, &Map.merge(&2, &1))
      |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)

    if var_string == "" do
      extra
    else
      "#{var_string}; #{extra}"
    end
  end

  defp merge_resolved_ref({:static, prop_classes}, props_acc, vars_acc) do
    merged = Enum.reduce(prop_classes, props_acc, &merge_prop_class/2)
    {merged, vars_acc}
  end

  defp merge_resolved_ref({:dynamic, class_string, var_map}, props_acc, vars_acc) do
    dyn_key = "__dynamic_#{:erlang.unique_integer([:positive])}__"
    {Map.put(props_acc, dyn_key, class_string), [var_map | vars_acc]}
  end

  defp merge_resolved_ref(:skip, props_acc, vars_acc), do: {props_acc, vars_acc}

  defp merge_prop_class({prop, :__unset__}, acc), do: Map.delete(acc, prop)
  defp merge_prop_class({prop, class}, acc), do: Map.put(acc, prop, class)

  defp resolve_ref_with_props(_module, ref, property_classes_map) when is_atom(ref) do
    prop_classes = Map.get(property_classes_map, ref, %{})
    {:static, prop_classes}
  end

  defp resolve_ref_with_props(_module, {other_module, name}, _property_classes_map)
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

  defp resolve_ref_with_props(module, {name, args}, _property_classes_map) when is_atom(name) do
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

  defp resolve_ref_with_props(_module, _ref, _property_classes_map), do: :skip
end
