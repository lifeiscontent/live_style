defmodule LiveStyle.Utils.CSS do
  @moduledoc false

  alias LiveStyle.Value

  @spec format_declarations(map() | keyword()) :: String.t()
  def format_declarations(declarations) do
    declarations
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {k, v} ->
      css_prop = Value.to_css_property(k)
      css_value = Value.to_css(v, css_prop)
      "#{css_prop}:#{css_value};"
    end)
  end
end
