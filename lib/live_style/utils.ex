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
  @spec format_declarations(keyword(), keyword()) :: String.t()
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

  def sort_conditional_value(value) when is_list(value) do
    # Skip typed value keyword lists (have :__type__, :syntax, etc. keys)
    cond do
      Keyword.has_key?(value, :__type__) -> value
      Keyword.has_key?(value, :syntax) -> value
      true -> sort_keyword_value(value)
    end
  end

  def sort_conditional_value(value), do: value

  defp sort_keyword_value(value) do
    if Keyword.keyword?(value) or tuple_list?(value) do
      value
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> {k, sort_conditional_value(v)} end)
    else
      value
    end
  end

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

  # ============================================================================
  # Tuple List Helpers
  #
  # These functions work with lists of 2-tuples where keys can be any term
  # (atoms, strings, structs, etc.), unlike Keyword which requires atom keys.
  # Used for conditional CSS values where keys include atoms (:default),
  # strings (":hover"), and complex terms (When.ancestor(":hover")).
  # ============================================================================

  @doc """
  Puts a value in a tuple list, replacing any existing entry with the same key.

  Similar to `List.keystore/4` but with a simpler API. Maintains insertion order
  by appending new keys at the end.

  ## Examples

      iex> LiveStyle.Utils.tuple_put([{:a, 1}], :b, 2)
      [{:a, 1}, {:b, 2}]

      iex> LiveStyle.Utils.tuple_put([{:a, 1}, {:b, 2}], :a, 3)
      [{:a, 3}, {:b, 2}]
  """
  @spec tuple_put(list({term(), term()}), term(), term()) :: list({term(), term()})
  def tuple_put(list, key, value) when is_list(list) do
    List.keystore(list, key, 0, {key, value})
  end

  @doc """
  Puts a value in a tuple list only if the key doesn't already exist.

  Similar to `Keyword.put_new/3` but works with any key type.
  Appends at the end to maintain insertion order.

  ## Examples

      iex> LiveStyle.Utils.tuple_put_new([{:a, 1}], :b, 2)
      [{:a, 1}, {:b, 2}]

      iex> LiveStyle.Utils.tuple_put_new([{:a, 1}], :a, 2)
      [{:a, 1}]
  """
  @spec tuple_put_new(list({term(), term()}), term(), term()) :: list({term(), term()})
  def tuple_put_new(list, key, value) when is_list(list) do
    case List.keyfind(list, key, 0) do
      nil -> list ++ [{key, value}]
      _ -> list
    end
  end

  @doc """
  Gets a value from a tuple list by key.

  Similar to `Keyword.get/3` but works with any key type.

  ## Examples

      iex> LiveStyle.Utils.tuple_get([{:a, 1}, {:b, 2}], :a)
      1

      iex> LiveStyle.Utils.tuple_get([{:a, 1}], :b)
      nil

      iex> LiveStyle.Utils.tuple_get([{:a, 1}], :b, :default)
      :default
  """
  @spec tuple_get(list({term(), term()}), term(), term()) :: term()
  def tuple_get(list, key, default \\ nil) when is_list(list) do
    case List.keyfind(list, key, 0) do
      {^key, value} -> value
      nil -> default
    end
  end

  @doc """
  Merges two tuple lists with last-wins semantics for duplicate keys.

  Values from the second list override values from the first list.

  ## Examples

      iex> LiveStyle.Utils.tuple_merge([{:a, 1}, {:b, 2}], [{:b, 3}, {:c, 4}])
      [{:a, 1}, {:b, 3}, {:c, 4}]
  """
  @spec tuple_merge(list({term(), term()}), list({term(), term()})) :: list({term(), term()})
  def tuple_merge(list1, list2) when is_list(list1) and is_list(list2) do
    Enum.reduce(list2, list1, fn {key, value}, acc ->
      tuple_put(acc, key, value)
    end)
  end

  @doc """
  Sorts a tuple list by key for deterministic iteration.

  Keys are converted to strings for comparison to handle mixed atom/string keys.

  ## Examples

      iex> LiveStyle.Utils.tuple_sort_by_key([{:b, 2}, {:a, 1}])
      [{:a, 1}, {:b, 2}]
  """
  @spec tuple_sort_by_key(list({term(), term()})) :: list({term(), term()})
  def tuple_sort_by_key(list) when is_list(list) do
    Enum.sort_by(list, fn {k, _v} -> to_string(k) end)
  end
end
