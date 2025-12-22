defmodule LiveStyle.Dev.Properties do
  @moduledoc false

  @spec extract_properties(map()) :: map()
  def extract_properties(metadata) do
    case metadata do
      %{atomic_classes: nil} ->
        %{}

      %{atomic_classes: atomic_classes} when is_map(atomic_classes) ->
        atomic_classes
        |> Enum.reject(fn {_prop, meta} -> meta == nil end)
        |> Enum.map(fn {prop, meta} -> extract_property_info(prop, meta) end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      _ ->
        %{}
    end
  end

  @spec build_css_string(map()) :: String.t()
  def build_css_string(properties) do
    properties
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.map_join(";", fn {prop, %{value: value}} -> "#{prop}:#{value}" end)
  end

  # Handle simple property structure: %{class: "x123", value: "red"}
  defp extract_property_info(prop, %{class: class, value: value}) when not is_nil(class) do
    {prop, %{class: class, value: value}}
  end

  # Handle conditional property structure: %{classes: %{:default => %{class: ..., value: ...}, ...}}
  defp extract_property_info(prop, %{classes: classes}) when is_map(classes) do
    case Map.get(classes, :default) || Map.get(classes, "default") do
      %{class: class, value: value} ->
        variants =
          classes
          |> Map.keys()
          |> Enum.reject(&(&1 == :default or &1 == "default"))

        {prop, %{class: class, value: value, variants: variants}}

      nil ->
        case Map.values(classes) |> List.first() do
          %{class: class, value: value} ->
            {prop, %{class: class, value: value, conditional: true}}

          _ ->
            nil
        end
    end
  end

  defp extract_property_info(_prop, _meta), do: nil
end
