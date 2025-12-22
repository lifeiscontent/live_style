defmodule LiveStyle.Value.Quote do
  @moduledoc false

  # Generate function clauses for content keywords
  @css_content_keywords ~w(normal none open-quote close-quote no-open-quote no-close-quote inherit initial revert revert-layer unset)

  for keyword <- @css_content_keywords do
    defp content_keyword?(unquote(keyword)), do: true
  end

  defp content_keyword?(_), do: false

  # Generate function clauses for hyphenate-character keywords
  @hyphenate_keywords ~w(auto inherit initial revert revert-layer unset)

  for keyword <- @hyphenate_keywords do
    defp hyphenate_keyword?(unquote(keyword)), do: true
  end

  defp hyphenate_keyword?(_), do: false

  # CSS function patterns that should not be quoted in content property
  @css_function_patterns [
    "attr(",
    "counter(",
    "counters(",
    "url(",
    "linear-gradient(",
    "image-set(",
    "var(--"
  ]

  @spec quote_content(String.t()) :: String.t()
  def quote_content(value) do
    val = String.trim(value)
    if skip_quoting_content?(val), do: val, else: "\"#{val}\""
  end

  @spec quote_hyphenate_character(String.t()) :: String.t()
  def quote_hyphenate_character(value) do
    val = String.trim(value)
    if skip_quoting_hyphenate?(val), do: val, else: "\"#{val}\""
  end

  defp skip_quoting_content?(val) do
    contains_css_function?(val) or content_keyword?(val) or has_matching_quotes?(val)
  end

  defp skip_quoting_hyphenate?(val) do
    hyphenate_keyword?(val) or has_matching_quotes?(val)
  end

  defp contains_css_function?(val) do
    Enum.any?(@css_function_patterns, &String.contains?(val, &1))
  end

  defp has_matching_quotes?(val) do
    count_char(val, ?") >= 2 or count_char(val, ?') >= 2
  end

  defp count_char(string, char) do
    string |> :binary.matches(<<char>>) |> length()
  end
end
