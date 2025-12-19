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

  @doc """
  Splits a CSS value string on whitespace, respecting parentheses nesting.

  This is used for parsing shorthand properties where values may contain
  functions like `rgb()`, `calc()`, etc.

  ## Examples

      iex> LiveStyle.Utils.split_css_value("10px 20px")
      ["10px", "20px"]

      iex> LiveStyle.Utils.split_css_value("rgb(0 0 0) 10px")
      ["rgb(0 0 0)", "10px"]

      iex> LiveStyle.Utils.split_css_value("calc(100% - 10px) auto")
      ["calc(100% - 10px)", "auto"]
  """
  @spec split_css_value(String.t()) :: [String.t()]
  def split_css_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> do_split_css_value([], "", 0)
  end

  def split_css_value(_value), do: []

  defp do_split_css_value("", acc, current, _depth) do
    case String.trim(current) do
      "" -> Enum.reverse(acc)
      trimmed -> Enum.reverse([trimmed | acc])
    end
  end

  defp do_split_css_value(<<" ", rest::binary>>, acc, current, 0) do
    case String.trim(current) do
      "" -> do_split_css_value(rest, acc, "", 0)
      trimmed -> do_split_css_value(rest, [trimmed | acc], "", 0)
    end
  end

  defp do_split_css_value(<<"(", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> "(", depth + 1)

  defp do_split_css_value(<<")", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> ")", max(0, depth - 1))

  defp do_split_css_value(<<char::utf8, rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> <<char::utf8>>, depth)
end
