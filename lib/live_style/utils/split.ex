defmodule LiveStyle.Utils.Split do
  @moduledoc false

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
