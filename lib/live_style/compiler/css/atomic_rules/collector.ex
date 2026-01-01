defmodule LiveStyle.Compiler.CSS.AtomicRules.Collector do
  @moduledoc false

  @type class_tuple ::
          {String.t(), String.t(), String.t(), String.t() | nil, String.t() | nil, list() | nil,
           String.t() | nil, non_neg_integer()}

  @spec collect(LiveStyle.Manifest.t()) :: [class_tuple()]
  def collect(manifest) do
    manifest.classes
    |> Enum.flat_map(fn {_key, entry} ->
      Enum.flat_map(entry.atomic_classes, &extract_class_tuples/1)
    end)
    |> Enum.uniq_by(fn {class_name, _, _, _, _, _, _, _} -> class_name end)
    |> Enum.sort_by(fn {_class_name, property, _value, _selector_suffix, _pseudo_element,
                        _fallback_values, _at_rule, priority} ->
      {priority, property}
    end)
  end

  # Extract class tuples from atomic_classes entries
  defp extract_class_tuples({_property, %{unset: true}}), do: []

  defp extract_class_tuples({property, %{class: class_name, value: value} = data})
       when not is_map_key(data, :classes) do
    [build_class_tuple(property, class_name, value, data)]
  end

  defp extract_class_tuples({property, %{classes: classes}}) do
    Enum.map(classes, fn {_condition, %{class: class_name, value: value} = data} ->
      build_class_tuple(property, class_name, value, data)
    end)
  end

  defp build_class_tuple(property, class_name, value, data) do
    {
      class_name,
      base_property(property),
      value,
      Map.get(data, :selector_suffix),
      Map.get(data, :pseudo_element),
      Map.get(data, :fallback_values),
      Map.get(data, :at_rule),
      Map.get(data, :priority, 3000)
    }
  end

  # Extract base property name (strips pseudo-element suffix like "::before")
  defp base_property(property) do
    property |> to_string() |> String.split("::") |> List.first()
  end
end
