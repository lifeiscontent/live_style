defmodule LiveStyle.Runtime.Attrs do
  @moduledoc false

  alias LiveStyle.CSSValue
  alias LiveStyle.Marker
  alias LiveStyle.Runtime.{PropertyMerger, RefResolver}

  @spec resolve_attrs(module(), list(), keyword() | nil) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, opts) when is_atom(module) and is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    {merged_props, var_styles, ordered_classes, _prop_classes_by_key} =
      refs
      |> List.flatten()
      |> Enum.reject(&falsy?/1)
      |> Enum.reduce({[], [], [], %{}}, &process_ref(&1, &2, module, property_classes_map))

    class_string =
      ordered_classes
      |> Enum.uniq()
      |> Enum.join(" ")

    extra_styles = extract_extra_styles(opts)
    style_string = build_style_string(var_styles, extra_styles)

    # Return Attrs with prop_classes for component merging
    %LiveStyle.Attrs{class: class_string, style: style_string, prop_classes: merged_props}
  end

  defp falsy?(nil), do: true
  defp falsy?(false), do: true
  defp falsy?(""), do: true
  defp falsy?(_), do: false

  defp process_ref(%Marker{class: class}, state, _module, _map) do
    append_class_string(state, class)
  end

  defp process_ref(%LiveStyle.Attrs{} = attrs, state, _module, _map) do
    process_attrs_ref(attrs, state)
  end

  defp process_ref(binary, state, _module, _map) when is_binary(binary) do
    append_class_string(state, binary)
  end

  defp process_ref(
         ref,
         {props_acc, vars_acc, class_order, prop_classes_by_key},
         module,
         property_classes_map
       ) do
    {new_props, new_vars, new_class_order, new_prop_classes_by_key} =
      RefResolver.resolve(module, ref, property_classes_map)
      |> merge_resolved_ref(props_acc, vars_acc, class_order, prop_classes_by_key)

    {new_props, new_vars, new_class_order, new_prop_classes_by_key}
  end

  defp process_attrs_ref(
         %LiveStyle.Attrs{prop_classes: prop_classes, class: class},
         {props_acc, vars_acc, class_order, prop_classes_by_key}
       )
       when is_list(prop_classes) and prop_classes != [] do
    # Merge the property classes from the Attrs struct
    new_props = PropertyMerger.merge(prop_classes, props_acc)

    {new_class_order, new_prop_classes_by_key} =
      apply_prop_classes(prop_classes, class_order, prop_classes_by_key)

    # Also preserve any extra classes (like markers) that aren't in prop_classes
    extra_from_attrs = extract_extra_classes(class, prop_classes)
    ordered_with_extra = new_class_order ++ extra_from_attrs

    {new_props, vars_acc, ordered_with_extra, new_prop_classes_by_key}
  end

  defp process_attrs_ref(
         %LiveStyle.Attrs{class: class},
         {props_acc, vars_acc, class_order, prop_classes_by_key}
       )
       when is_binary(class) and class != "" do
    # No property classes - treat as extra class string
    {props_acc, vars_acc, class_order ++ split_class_string(class), prop_classes_by_key}
  end

  defp process_attrs_ref(
         %LiveStyle.Attrs{},
         {props_acc, vars_acc, class_order, prop_classes_by_key}
       ) do
    {props_acc, vars_acc, class_order, prop_classes_by_key}
  end

  defp extract_extra_classes(class, prop_classes) when is_binary(class) and class != "" do
    prop_class_values = MapSet.new(Enum.map(prop_classes, fn {_prop, cls} -> cls end))

    class
    |> String.split(" ", trim: true)
    |> Enum.reject(&MapSet.member?(prop_class_values, &1))
  end

  defp extract_extra_classes(_, _), do: []

  defp extract_extra_styles(nil), do: nil
  defp extract_extra_styles([]), do: nil

  defp extract_extra_styles(opts) when is_list(opts) do
    case Keyword.get(opts, :style) do
      nil -> nil
      styles when is_binary(styles) -> styles
      styles when is_list(styles) -> format_extra_styles(styles)
    end
  end

  defp format_extra_styles(styles) when is_list(styles) do
    Enum.map_join(styles, "; ", fn {key, value} ->
      css_prop = format_style_key(key)
      "#{css_prop}: #{value}"
    end)
  end

  defp format_style_key(key) when is_atom(key), do: CSSValue.to_css_property(key)
  defp format_style_key(key) when is_binary(key), do: key

  defp build_style_string([], nil), do: nil
  defp build_style_string([], extra) when is_binary(extra), do: extra

  defp build_style_string(var_styles, nil) do
    var_styles
    |> Enum.reverse()
    |> Enum.reduce([], &merge_var_list/2)
    |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)
  end

  defp build_style_string(var_styles, extra) when is_binary(extra) do
    var_string =
      var_styles
      |> Enum.reverse()
      |> Enum.reduce([], &merge_var_list/2)
      |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)

    if var_string == "" do
      extra
    else
      "#{var_string}; #{extra}"
    end
  end

  defp merge_var_list(new_vars, acc) when is_list(new_vars) do
    Enum.reduce(new_vars, acc, fn {key, value}, inner_acc ->
      List.keystore(inner_acc, key, 0, {key, value})
    end)
  end

  defp merge_resolved_ref(
         {:static, prop_classes},
         props_acc,
         vars_acc,
         class_order,
         prop_classes_by_key
       ) do
    merged = PropertyMerger.merge(prop_classes, props_acc)

    {new_class_order, new_prop_classes_by_key} =
      apply_prop_classes(prop_classes, class_order, prop_classes_by_key)

    {merged, vars_acc, new_class_order, new_prop_classes_by_key}
  end

  defp merge_resolved_ref(
         {:dynamic, prop_classes, var_list},
         props_acc,
         vars_acc,
         class_order,
         prop_classes_by_key
       ) do
    # Dynamic classes now merge by property just like static classes (StyleX behavior)
    merged = PropertyMerger.merge(prop_classes, props_acc)

    {new_class_order, new_prop_classes_by_key} =
      apply_prop_classes(prop_classes, class_order, prop_classes_by_key)

    {merged, [var_list | vars_acc], new_class_order, new_prop_classes_by_key}
  end

  defp merge_resolved_ref(:skip, props_acc, vars_acc, class_order, prop_classes_by_key) do
    {props_acc, vars_acc, class_order, prop_classes_by_key}
  end

  defp append_class_string({props_acc, vars_acc, class_order, prop_classes_by_key}, class_string) do
    {props_acc, vars_acc, class_order ++ split_class_string(class_string), prop_classes_by_key}
  end

  defp split_class_string(class_string) when is_binary(class_string) do
    String.split(class_string, " ", trim: true)
  end

  defp apply_prop_classes(prop_classes, class_order, prop_classes_by_key)
       when is_list(prop_classes) do
    Enum.reduce(prop_classes, {class_order, prop_classes_by_key}, fn
      {prop_key, :__unset__}, {order_acc, prop_map_acc} ->
        case Map.pop(prop_map_acc, prop_key) do
          {nil, updated_map} ->
            {order_acc, updated_map}

          {old_class, updated_map} ->
            {remove_last(order_acc, old_class), updated_map}
        end

      {prop_key, class_name}, {order_acc, prop_map_acc}
      when is_binary(class_name) and class_name != "" ->
        {trimmed_order, updated_map} =
          case Map.pop(prop_map_acc, prop_key) do
            {nil, map_without_prop} ->
              {order_acc, map_without_prop}

            {old_class, map_without_prop} ->
              {remove_last(order_acc, old_class), map_without_prop}
          end

        {trimmed_order ++ [class_name], Map.put(updated_map, prop_key, class_name)}

      _entry, acc ->
        acc
    end)
  end

  defp remove_last(list, target) do
    list
    |> Enum.reverse()
    |> remove_first_reversed(target)
    |> Enum.reverse()
  end

  defp remove_first_reversed([target | rest], target), do: rest

  defp remove_first_reversed([head | rest], target),
    do: [head | remove_first_reversed(rest, target)]

  defp remove_first_reversed([], _target), do: []
end
