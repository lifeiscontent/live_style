defmodule LiveStyle.CSSValue.Normalize do
  @moduledoc false

  # Compile regex patterns at module level (compiled once, reused)
  @whitespace_comma_regex ~r/\s*,\s*/
  @multiple_spaces_regex ~r/\s{2,}/
  @important_space_regex ~r/\s+!important/
  @open_paren_space_regex ~r/\(\s+/
  @close_paren_space_regex ~r/\s+\)/
  @ms_timing_regex ~r/(\d+(?:\.\d+)?)ms\b/
  @leading_zero_regex ~r/(?<![0-9])0\.(\d+)/
  @zero_angle_regex ~r/\b0(deg|grad|turn|rad)\b/
  @zero_timing_regex ~r/\b0(ms|s)\b/
  @zero_length_regex ~r/\b0(px|em|rem|vh|vw|vmin|vmax|ch|ex|cm|mm|in|pt|pc|dvh|dvw|lvh|lvw|svh|svw)\b/
  @zero_length_careful_regex ~r/\b0(px|em|rem|vh|vw|vmin|vmax|ch|ex|cm|mm|in|pt|pc|dvh|dvw|lvh|lvw|svh|svw)(?=\s*[;,}\)]|$)/

  @spec normalize(String.t()) :: String.t()
  def normalize(value) when is_binary(value) do
    value
    |> normalize_whitespace()
    |> normalize_timings()
    |> normalize_leading_zeros()
    |> normalize_zero_dimensions()
    |> normalize_empty_quotes()
  end

  # Normalize whitespace (matching StyleX's whitespace.js)
  defp normalize_whitespace(value) do
    value
    |> String.trim()
    |> String.replace(@whitespace_comma_regex, ",")
    |> String.replace(@multiple_spaces_regex, " ")
    |> normalize_function_whitespace()
    |> String.replace(@important_space_regex, "!important")
  end

  defp normalize_function_whitespace(value) do
    value
    |> String.replace(@open_paren_space_regex, "(")
    |> String.replace(@close_paren_space_regex, ")")
  end

  # Convert milliseconds to seconds when >= 10ms
  defp normalize_timings(value) do
    Regex.replace(@ms_timing_regex, value, fn _, num_str ->
      num = String.to_float(num_str <> ".0") |> Float.round(4)

      if num >= 10 do
        seconds = num / 1000
        "#{seconds}s"
      else
        "#{num_str}ms"
      end
    end)
  end

  # Remove leading zeros for 0 <= x < 1
  defp normalize_leading_zeros(value) do
    Regex.replace(@leading_zero_regex, value, ".\\1")
  end

  # Normalize zero dimensions
  defp normalize_zero_dimensions(value) do
    if String.contains?(value, "(") do
      normalize_zero_dimensions_careful(value)
    else
      value
      |> normalize_zero_angle()
      |> normalize_zero_timing()
      |> normalize_zero_length()
    end
  end

  defp normalize_zero_dimensions_careful(value) do
    value
    |> normalize_zero_angle()
    |> normalize_zero_timing()
    |> normalize_zero_length_careful()
  end

  defp normalize_zero_angle(value), do: Regex.replace(@zero_angle_regex, value, "0deg")
  defp normalize_zero_timing(value), do: Regex.replace(@zero_timing_regex, value, "0s")
  defp normalize_zero_length(value), do: Regex.replace(@zero_length_regex, value, "0")

  defp normalize_zero_length_careful(value) do
    Regex.replace(@zero_length_careful_regex, value, "0")
  end

  # StyleX: Make empty strings use consistent double quotes
  defp normalize_empty_quotes(value) do
    String.replace(value, "''", "\"\"")
  end
end
