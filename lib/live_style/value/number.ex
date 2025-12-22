defmodule LiveStyle.Value.Number do
  @moduledoc false

  alias LiveStyle.Property
  alias LiveStyle.Value.Normalize

  @spec to_css(number(), String.t() | nil) :: String.t()
  def to_css(v, property) when is_number(v) do
    rounded = round_number(v)
    suffix = get_number_suffix(property)
    value = "#{rounded}#{suffix}"

    if property == "font-size" and suffix == "px" and LiveStyle.Config.font_size_px_to_rem?() do
      px_to_rem(v)
    else
      Normalize.normalize(value)
    end
  end

  defp round_number(v) when is_integer(v), do: Integer.to_string(v)

  defp round_number(v) when is_float(v) do
    rounded = Float.round(v * 10_000) / 10_000

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      :erlang.float_to_binary(rounded, decimals: 4)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    end
  end

  defp get_number_suffix(property), do: Property.unit_suffix(property)

  defp px_to_rem(px_value) do
    root_px = LiveStyle.Config.font_size_root_px()
    rem_value = px_value / root_px

    formatted =
      if rem_value == trunc(rem_value) do
        Integer.to_string(trunc(rem_value))
      else
        :erlang.float_to_binary(Float.round(rem_value, 4), decimals: 4)
        |> String.trim_trailing("0")
        |> String.trim_trailing(".")
      end

    "#{formatted}rem"
  end
end
