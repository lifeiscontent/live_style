defmodule LiveStyle.Dev.Properties do
  @moduledoc false

  @spec extract_properties(map()) :: list()
  def extract_properties(metadata) do
    case metadata do
      %{atomic_classes: nil} ->
        []

      %{atomic_classes: atomic_classes} when is_list(atomic_classes) ->
        atomic_classes
        |> Enum.reject(fn {_prop, meta} -> meta == nil end)
        |> Enum.map(fn {prop, meta} -> extract_property_info(prop, meta) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @spec build_css_string(list()) :: String.t()
  def build_css_string(properties) do
    properties
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.map_join(";", fn {prop, %{value: value}} -> "#{prop}:#{value}" end)
  end

  # Handle simple property structure: [class: "x123", value: "red"]
  defp extract_property_info(prop, entry) when is_list(entry) do
    class = Keyword.get(entry, :class)
    value = Keyword.get(entry, :value)
    classes = Keyword.get(entry, :classes)

    cond do
      classes != nil and is_list(classes) ->
        extract_conditional_info(prop, classes)

      class != nil ->
        {prop, %{class: class, value: value}}

      true ->
        nil
    end
  end

  defp extract_property_info(_prop, _meta), do: nil

  # Handle conditional property structure: [classes: [...]]
  defp extract_conditional_info(prop, classes) do
    default_entry = List.keyfind(classes, :default, 0) || List.keyfind(classes, "default", 0)

    case default_entry do
      {_, entry} when is_list(entry) ->
        class = Keyword.get(entry, :class)
        value = Keyword.get(entry, :value)

        variants =
          classes
          |> Enum.map(fn {k, _} -> k end)
          |> Enum.reject(&(&1 == :default or &1 == "default"))

        {prop, %{class: class, value: value, variants: variants}}

      nil ->
        case classes do
          [{_, entry} | _] when is_list(entry) ->
            class = Keyword.get(entry, :class)
            value = Keyword.get(entry, :value)
            {prop, %{class: class, value: value, conditional: true}}

          _ ->
            nil
        end
    end
  end
end
