defmodule LiveStyle.PropertyType.Helpers do
  @moduledoc false

  @spec typed?(any()) :: boolean()
  def typed?(%{__type__: :typed_var}), do: true
  def typed?(_), do: false

  @spec initial_value(LiveStyle.PropertyType.typed_value()) :: String.t()
  def initial_value(%{value: %{default: default}}) when is_binary(default), do: default
  def initial_value(%{value: value}) when is_binary(value), do: value
  def initial_value(%{value: value}) when is_integer(value), do: to_string(value)
  def initial_value(%{value: value}) when is_float(value), do: to_string(value)

  def initial_value(%{value: %{} = map}) do
    case Map.get(map, :default) do
      nil -> map |> Map.values() |> List.first() |> to_string()
      val -> to_string(val)
    end
  end

  @spec unwrap_value(LiveStyle.PropertyType.typed_value()) :: String.t() | map()
  def unwrap_value(%{value: value}), do: value
end
