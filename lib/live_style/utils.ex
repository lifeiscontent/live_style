defmodule LiveStyle.Utils do
  @moduledoc """
  Common utility functions shared across LiveStyle modules.
  """

  alias LiveStyle.CSSValue

  @doc """
  Validates that the input is a keyword list (not a map).

  Maps are not supported because they don't preserve insertion order,
  which is required for StyleX-compatible CSS output.

  Raises ArgumentError if a map is passed.
  """
  @spec validate_keyword_list!(keyword()) :: keyword()
  def validate_keyword_list!(value) when is_list(value), do: value

  def validate_keyword_list!(value) when is_map(value) do
    raise ArgumentError, """
    Maps are not supported for style declarations. Use keyword lists instead.

    Maps don't preserve insertion order, which can cause non-deterministic CSS output.

    Instead of:
      %{color: "red", background: "blue"}

    Use:
      [color: "red", background: "blue"]

    Got: #{inspect(value)}
    """
  end

  @doc """
  Merges two declaration lists with last-wins semantics.

  Keys from the second list override keys from the first list.
  Order is preserved: base keys first (excluding overridden), then override keys.

  Supports both keyword lists (atom keys) and general tuple lists (string keys
  for CSS custom properties).

  ## Examples

      iex> LiveStyle.Utils.merge_declarations([a: 1, b: 2], [b: 3, c: 4])
      [a: 1, b: 3, c: 4]
  """
  @spec merge_declarations(list(), list()) :: list()
  def merge_declarations(base, overrides) when is_list(base) and is_list(overrides) do
    override_keys = Enum.map(overrides, fn {k, _v} -> k end) |> MapSet.new()

    # Keep base keys that aren't overridden, then append all overrides
    filtered_base = Enum.filter(base, fn {k, _v} -> not MapSet.member?(override_keys, k) end)
    filtered_base ++ overrides
  end

  @doc """
  Formats CSS declarations as a minified string.

  Converts a map of property/value pairs to minified CSS format (prop:value;).

  ## Options

  - `:sort` - Whether to sort properties alphabetically. Defaults to `true`.
    Set to `false` to preserve insertion order (for StyleX parity with keyframes
    and view-transitions which use JavaScript's Object.entries order).
  """
  @spec format_declarations(map() | keyword(), keyword()) :: String.t()
  def format_declarations(declarations, opts \\ []) do
    sort = Keyword.get(opts, :sort, true)

    declarations
    |> maybe_sort(sort)
    |> Enum.map_join("", fn {k, v} ->
      css_prop = CSSValue.to_css_property(k)
      css_value = CSSValue.to_css(v, css_prop)
      "#{css_prop}:#{css_value};"
    end)
  end

  defp maybe_sort(decls, true), do: Enum.sort_by(decls, fn {k, _} -> to_string(k) end)
  defp maybe_sort(decls, false), do: decls

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
  Recursively sorts conditional list keys for deterministic iteration order.

  Conditional values are keyword lists with keys like `:default`, `"@media ..."`, etc.
  Sorting once at storage time avoids repeated sorting during CSS generation.

  Special structures (like fallback tuples and typed var maps) are preserved as-is.
  Maps are NOT supported for conditional values - use keyword lists instead.
  """
  @spec sort_conditional_value(term()) :: term()
  # Skip special structures that shouldn't be sorted (fallback values, typed vars, etc.)
  def sort_conditional_value({:__fallback__, _} = value), do: value
  def sort_conditional_value(%{__css_type__: _} = value), do: value
  def sort_conditional_value(%{__type__: _} = value), do: value
  def sort_conditional_value(%{syntax: _} = value), do: value

  def sort_conditional_value(value) when is_list(value) do
    if Keyword.keyword?(value) or tuple_list?(value) do
      value
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> {k, sort_conditional_value(v)} end)
    else
      value
    end
  end

  def sort_conditional_value(value), do: value

  defp tuple_list?([{_, _} | _]), do: true
  defp tuple_list?(_), do: false

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
