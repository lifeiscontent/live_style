defmodule LiveStyle.Utils.Normalize do
  @moduledoc false

  @spec normalize_to_map(map() | keyword()) :: map()
  def normalize_to_map(value) when is_map(value), do: value
  def normalize_to_map(value) when is_list(value), do: Map.new(value)
end
