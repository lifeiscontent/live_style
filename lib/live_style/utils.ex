defmodule LiveStyle.Utils do
  @moduledoc """
  Common utility functions shared across LiveStyle modules.
  """

  alias LiveStyle.Value

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

  @doc """
  Formats CSS declarations as a minified string.

  Converts a map of property/value pairs to minified CSS format (prop:value;).
  Properties are sorted alphabetically for consistent output.

  ## Examples

      iex> LiveStyle.Utils.format_declarations(%{display: "flex", margin: 0})
      "display:flex;margin:0;"
  """
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
