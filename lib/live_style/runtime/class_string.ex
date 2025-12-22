defmodule LiveStyle.Runtime.ClassString do
  @moduledoc false

  @spec resolve_class_string(module(), list()) :: String.t()
  def resolve_class_string(module, refs) when is_atom(module) and is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    merged =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce(%{}, fn ref, acc ->
        merge_ref_classes(module, ref, property_classes_map, acc)
      end)

    merged
    |> Map.values()
    |> Enum.reject(&(&1 == :__unset__ or &1 == nil))
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  defp merge_ref_classes(_module, ref, property_classes_map, acc) when is_atom(ref) do
    prop_classes = Map.get(property_classes_map, ref, %{})

    Enum.reduce(prop_classes, acc, fn
      {prop, :__unset__}, acc_inner ->
        Map.delete(acc_inner, prop)

      {prop, class}, acc_inner ->
        Map.put(acc_inner, prop, class)
    end)
  end

  defp merge_ref_classes(_module, {other_module, name}, _property_classes_map, acc)
       when is_atom(other_module) and is_atom(name) do
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Map.get(other_prop_classes, name, %{})

        Enum.reduce(prop_classes, acc, fn
          {prop, :__unset__}, acc_inner ->
            Map.delete(acc_inner, prop)

          {prop, class}, acc_inner ->
            Map.put(acc_inner, prop, class)
        end)

      _ ->
        acc
    end
  end

  defp merge_ref_classes(_module, _ref, _property_classes_map, acc), do: acc
end
