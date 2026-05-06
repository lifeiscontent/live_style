defmodule LiveStyle.Runtime.Attrs do
  @moduledoc false

  alias LiveStyle.CSSValue
  alias LiveStyle.Marker
  alias LiveStyle.Runtime.{RefResolver, StyleMerger}

  @spec resolve_attrs(module(), list(), keyword() | nil) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, opts) when is_atom(module) and is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    state =
      refs
      |> List.flatten()
      |> Enum.reject(&falsy?/1)
      |> Enum.reduce(StyleMerger.new_state(), fn ref, state ->
        if resolved_value_ref?(ref) do
          merge_value_ref(ref, state)
        else
          resolve_and_merge_ref(ref, state, module, property_classes_map)
        end
      end)

    extra_styles = extract_extra_styles(opts)
    StyleMerger.to_attrs(state, extra_styles)
  end

  defp falsy?(nil), do: true
  defp falsy?(false), do: true
  defp falsy?(""), do: true
  defp falsy?(_), do: false

  defp resolved_value_ref?(%Marker{}), do: true
  defp resolved_value_ref?(%LiveStyle.Attrs{}), do: true
  defp resolved_value_ref?(binary) when is_binary(binary), do: true
  defp resolved_value_ref?(_ref), do: false

  defp merge_value_ref(%Marker{class: class}, state) do
    StyleMerger.append_class_string(state, class)
  end

  defp merge_value_ref(%LiveStyle.Attrs{} = attrs, state) do
    process_attrs_ref(attrs, state)
  end

  defp merge_value_ref(binary, state) when is_binary(binary) do
    StyleMerger.append_class_string(state, binary)
  end

  defp resolve_and_merge_ref(ref, state, module, property_classes_map) do
    module
    |> RefResolver.resolve(ref, property_classes_map)
    |> StyleMerger.merge_resolved(state)
  end

  defp process_attrs_ref(
         %LiveStyle.Attrs{
           prop_classes: {:live_style_static_refs, source_module, refs}
         } = attrs,
         state
       )
       when is_atom(source_module) and is_list(refs) do
    resolved = resolve_attrs(source_module, refs, nil)
    StyleMerger.merge_attrs(%{attrs | prop_classes: resolved.prop_classes}, state)
  end

  defp process_attrs_ref(%LiveStyle.Attrs{} = attrs, state),
    do: StyleMerger.merge_attrs(attrs, state)

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
end
