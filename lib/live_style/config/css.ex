defmodule LiveStyle.Config.CSS do
  @moduledoc false

  @spec apply_prefix_css(String.t(), String.t()) :: String.t()
  def apply_prefix_css(property, value) do
    case LiveStyle.Config.prefix_css() do
      nil -> "#{property}:#{value}"
      prefix_fun -> prefix_fun.(property, value)
    end
  end
end
