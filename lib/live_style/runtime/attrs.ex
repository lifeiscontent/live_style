defmodule LiveStyle.Runtime.Attrs do
  @moduledoc false

  alias LiveStyle.CSSValue
  alias LiveStyle.Marker
  alias LiveStyle.Runtime.{PropertyMerger, RefResolver}

  @spec resolve_attrs(module(), list(), keyword() | nil) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, opts) when is_atom(module) and is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    {merged_props, var_styles, extra_classes} =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false or &1 == ""))
      |> Enum.reduce({[], [], []}, fn ref, {props_acc, vars_acc, extra_acc} ->
        case ref do
          %Marker{class: class} ->
            {props_acc, vars_acc, [class | extra_acc]}

          binary when is_binary(binary) ->
            {props_acc, vars_acc, [binary | extra_acc]}

          _ ->
            {new_props, new_vars} =
              RefResolver.resolve(module, ref, property_classes_map)
              |> merge_resolved_ref(props_acc, vars_acc)

            {new_props, new_vars, extra_acc}
        end
      end)

    class_list = PropertyMerger.to_class_list(merged_props)

    class_string =
      (class_list ++ Enum.reverse(extra_classes))
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

  defp merge_resolved_ref({:static, prop_classes}, props_acc, vars_acc) do
    merged = PropertyMerger.merge(prop_classes, props_acc)
    {merged, vars_acc}
  end

  defp merge_resolved_ref({:dynamic, prop_classes, var_list}, props_acc, vars_acc) do
    # Dynamic classes now merge by property just like static classes (StyleX behavior)
    merged = PropertyMerger.merge(prop_classes, props_acc)
    {merged, [var_list | vars_acc]}
  end

  defp merge_resolved_ref(:skip, props_acc, vars_acc), do: {props_acc, vars_acc}
end
