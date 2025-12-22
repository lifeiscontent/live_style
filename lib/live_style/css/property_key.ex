defmodule LiveStyle.CSS.PropertyKey do
  @moduledoc false

  @spec base(String.t() | atom()) :: String.t()
  def base(property) do
    property
    |> to_string()
    |> String.split("::")
    |> List.first()
  end
end
