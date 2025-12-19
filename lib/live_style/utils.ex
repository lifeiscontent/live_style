defmodule LiveStyle.Utils do
  @moduledoc """
  Common utility functions shared across LiveStyle modules.
  """

  @doc """
  Normalizes a keyword list or map to a map.

  Accepts both maps (returned as-is) and keyword lists (converted to maps).
  This is commonly used to accept flexible input in macro APIs.

  ## Examples

      iex> LiveStyle.Utils.normalize_to_map(%{a: 1})
      %{a: 1}

      iex> LiveStyle.Utils.normalize_to_map([a: 1, b: 2])
      %{a: 1, b: 2}
  """
  @spec normalize_to_map(map() | keyword()) :: map()
  def normalize_to_map(value) when is_map(value), do: value
  def normalize_to_map(value) when is_list(value), do: Map.new(value)
end
