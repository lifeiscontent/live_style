defmodule LiveStyle.Compiler.CSS.AtomicRules.Collector do
  @moduledoc false

  @type class_tuple ::
          {String.t(), String.t(), String.t(), String.t() | nil, String.t() | nil, list() | nil,
           String.t() | nil, non_neg_integer()}

  @spec collect(LiveStyle.Manifest.t()) :: [class_tuple()]
  def collect(manifest) do
    manifest.classes
    # Sort by key for deterministic iteration order across Elixir/OTP versions
    |> Enum.sort_by(fn {key, _entry} -> key end)
    |> Enum.flat_map(fn {_key, entry} ->
      # Sort atomic_classes by property name for deterministic order
      entry.atomic_classes
      |> Enum.sort_by(fn {prop, _data} -> prop end)
      |> Enum.flat_map(&extract_class_tuples/1)
    end)
    |> Enum.uniq_by(fn {class_name, _, _, _, _, _, _, _} -> class_name end)
    |> Enum.sort_by(fn {class_name, property, _value, _selector_suffix, _pseudo_element,
                        _fallback_values, _at_rule, priority} ->
      {priority, property, class_name}
    end)
  end

  # Extract class tuples from atomic_classes entries
  defp extract_class_tuples({property, data}) when is_list(data) do
    cond do
      Keyword.get(data, :unset) == true ->
        []

      Keyword.has_key?(data, :classes) ->
        classes = Keyword.get(data, :classes)

        Enum.map(classes, fn {_condition, entry} ->
          class_name = Keyword.get(entry, :class)
          value = Keyword.get(entry, :value)
          build_class_tuple(property, class_name, value, entry)
        end)

      true ->
        class_name = Keyword.get(data, :class)
        value = Keyword.get(data, :value)
        [build_class_tuple(property, class_name, value, data)]
    end
  end

  defp build_class_tuple(property, class_name, value, data) do
    {
      class_name,
      base_property(property),
      value,
      Keyword.get(data, :selector_suffix),
      Keyword.get(data, :pseudo_element),
      Keyword.get(data, :fallback_values),
      Keyword.get(data, :at_rule),
      Keyword.get(data, :priority, 3000)
    }
  end

  # Extract base property name (strips pseudo-element suffix like "::before")
  defp base_property(property) do
    property |> to_string() |> String.split("::") |> List.first()
  end
end
