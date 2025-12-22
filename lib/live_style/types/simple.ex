defmodule LiveStyle.Types.Simple do
  @moduledoc false

  # Type definitions: {function_name, css_syntax}
  @simple_types [
    {:color, "<color>"},
    {:length, "<length>"},
    {:angle, "<angle>"},
    {:time, "<time>"},
    {:percentage, "<percentage>"},
    {:url, "<url>"},
    {:image, "<image>"},
    {:resolution, "<resolution>"},
    {:length_percentage, "<length-percentage>"},
    {:transform_function, "<transform-function>"},
    {:transform_list, "<transform-list>"}
  ]

  @spec atom_to_syntax(atom()) :: String.t()
  for {name, syntax} <- @simple_types do
    def atom_to_syntax(unquote(name)), do: unquote(syntax)
  end

  def atom_to_syntax(:integer), do: "<integer>"
  def atom_to_syntax(:number), do: "<number>"
  def atom_to_syntax(other), do: "<#{other}>"

  for {name, syntax} <- @simple_types do
    @spec unquote(name)(String.t() | map()) :: LiveStyle.Types.typed_value()
    def unquote(name)(value) do
      %{__type__: :typed_var, syntax: unquote(syntax), value: value}
    end
  end
end
