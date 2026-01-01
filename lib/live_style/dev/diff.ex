defmodule LiveStyle.Dev.Diff do
  @moduledoc false

  alias LiveStyle.Dev.Ensure

  @spec diff(module(), list()) :: map()
  def diff(module, refs) when is_atom(module) and is_list(refs) do
    Ensure.ensure_live_style_module!(module)

    merged_class = LiveStyle.Compiler.get_css_class(module, refs)
    property_classes = module.__live_style__(:property_classes)

    properties =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce(%{}, fn ref, acc ->
        case get_ref_properties(ref, property_classes) do
          nil -> acc
          props -> merge_with_source(acc, props, ref)
        end
      end)

    %{
      merged_class: merged_class,
      refs: refs,
      properties: properties
    }
  end

  defp get_ref_properties(ref, property_classes) when is_atom(ref) do
    Map.get(property_classes, ref)
  end

  defp get_ref_properties(_ref, _property_classes), do: nil

  defp merge_with_source(acc, props, source_ref) do
    Enum.reduce(props, acc, fn {prop_key, class_name}, inner_acc ->
      value = get_property_value(prop_key, class_name)
      Map.put(inner_acc, prop_key, %{value: value, class: class_name, from: source_ref})
    end)
  end

  defp get_property_value(_prop_key, class_name) do
    manifest = LiveStyle.Storage.read()

    manifest
    |> Map.get(:classes, %{})
    |> Enum.find_value(fn {_key, class_data} ->
      find_value_in_class_data(class_data, class_name)
    end)
  end

  defp find_value_in_class_data(%{atomic_classes: atomic_classes}, class_name)
       when is_map(atomic_classes) do
    Enum.find_value(atomic_classes, fn
      {_prop, %{class: ^class_name, value: value}} ->
        value

      {_prop, %{classes: nested_classes}} when is_map(nested_classes) ->
        Enum.find_value(nested_classes, fn
          {_variant, %{class: ^class_name, value: value}} -> value
          _ -> nil
        end)

      _ ->
        nil
    end)
  end

  defp find_value_in_class_data(_, _), do: nil
end
