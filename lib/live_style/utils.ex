defmodule LiveStyle.Utils do
  @moduledoc """
  Common utility functions shared across LiveStyle modules.
  """

  alias LiveStyle.CSSValue

  @doc """
  Normalizes a keyword list or map to a map.

  Accepts both maps (returned as-is) and keyword lists (converted to maps).
  This is commonly used to accept flexible input in macro APIs.
  """
  @spec normalize_to_map(map() | keyword()) :: map()
  def normalize_to_map(value) when is_map(value), do: value

  def normalize_to_map(value) when is_list(value) do
    {includes, declarations} =
      Enum.split_with(value, fn
        {:__include__, _ref} -> true
        _ -> false
      end)

    base = Map.new(declarations)

    case includes do
      [] ->
        base

      includes_list ->
        refs = Enum.map(includes_list, fn {:__include__, ref} -> ref end)
        Map.put(base, :__include__, refs)
    end
  end

  @doc """
  Formats CSS declarations as a minified string.

  Converts a map of property/value pairs to minified CSS format (prop:value;).
  Properties are sorted alphabetically for consistent output.
  """
  @spec format_declarations(map() | keyword()) :: String.t()
  def format_declarations(declarations) do
    declarations
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {k, v} ->
      css_prop = CSSValue.to_css_property(k)
      css_value = CSSValue.to_css(v, css_prop)
      "#{css_prop}:#{css_value};"
    end)
  end

  @doc """
  Splits a CSS value string on whitespace, respecting parentheses nesting.

  This is used for parsing shorthand properties where values may contain
  functions like `rgb()`, `calc()`, etc.
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

  @doc """
  Finds the last index in a list where the predicate returns true.

  Returns -1 if no element matches.

  ## Examples

      iex> LiveStyle.Utils.find_last_index([1, 2, 3, 2], &(&1 == 2))
      3

      iex> LiveStyle.Utils.find_last_index([1, 2, 3], &(&1 == 5))
      -1
  """
  @spec find_last_index(list(), (any() -> boolean())) :: integer()
  def find_last_index(list, pred) when is_list(list) and is_function(pred, 1) do
    list
    |> Enum.with_index()
    |> Enum.reduce(-1, fn {val, idx}, acc -> if pred.(val), do: idx, else: acc end)
  end
end
