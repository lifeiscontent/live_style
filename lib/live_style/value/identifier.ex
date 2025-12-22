defmodule LiveStyle.Value.Identifier do
  @moduledoc false

  @spec convert_snake_case_to_dash_case(String.t()) :: String.t()
  def convert_snake_case_to_dash_case(value) do
    value
    |> String.split(",")
    |> Enum.map_join(",", fn part ->
      part = String.trim(part)

      case part do
        <<"--", _rest::binary>> -> part
        _ -> String.replace(part, "_", "-")
      end
    end)
  end
end
