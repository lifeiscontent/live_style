defmodule LiveStyle.Value do
  @moduledoc """
  CSS value normalization and transformation.

  Follows StyleX's transform-value.js and normalize-value.js approach.

  Delegates property checks to `LiveStyle.Property` for centralized
  compile-time generated lookups.
  Regex patterns are compiled at module level for efficiency.
  """

  alias LiveStyle.Property

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

  @doc """
  Converts a value to its CSS string representation.

  ## Examples

      iex> LiveStyle.Value.to_css(10, "padding")
      "10px"

      iex> LiveStyle.Value.to_css(0.5, "opacity")
      "0.5"

      iex> LiveStyle.Value.to_css("0.5s", "transition-duration")
      ".5s"
  """
  @spec to_css(any(), String.t() | nil) :: String.t()
  def to_css(v, property) when is_number(v) do
    rounded = round_number(v)
    suffix = get_number_suffix(property)
    value = "#{rounded}#{suffix}"

    # Convert font-size px to rem if enabled
    if property == "font-size" and suffix == "px" and LiveStyle.Config.font_size_px_to_rem?() do
      px_to_rem(v)
    else
      # Apply full normalization to numeric values too (including 0px -> 0)
      normalize(value)
    end
  end

  # content needs special quoting handling
  def to_css(v, "content") when is_binary(v), do: v |> normalize() |> quote_content_value()

  # hyphenate-character needs special quoting handling
  # but "auto" is a valid keyword that shouldn't be quoted
  def to_css(v, "hyphenate-character") when is_binary(v),
    do: v |> normalize() |> quote_hyphenate_character_value()

  # For transition-property and will-change, convert snake_case strings to dash-case
  # e.g., "background_color" -> "background-color"
  # This is the Elixir idiom equivalent of StyleX's camelCase -> kebab-case
  def to_css(v, "transition-property") when is_binary(v),
    do: v |> normalize() |> convert_snake_case_to_dash_case()

  def to_css(v, "will-change") when is_binary(v),
    do: v |> normalize() |> convert_snake_case_to_dash_case()

  def to_css(v, _property) when is_binary(v), do: normalize(v)

  # nil is not a valid CSS value - catch this explicitly rather than letting
  # it fall through to to_string(nil) which would produce "nil"
  def to_css(nil, property) do
    raise ArgumentError,
          "Invalid property value: `nil` is not a valid CSS value for property `#{property}`"
  end

  # Boolean values are not valid CSS values - StyleX throws ILLEGAL_PROP_VALUE
  def to_css(true, _property) do
    raise ArgumentError, "Invalid property value: boolean `true` is not a valid CSS value"
  end

  def to_css(false, _property) do
    raise ArgumentError, "Invalid property value: boolean `false` is not a valid CSS value"
  end

  # For transition-property and will-change, convert snake_case atoms to dash-case
  # e.g., :background_color -> "background-color"
  def to_css(v, "transition-property") when is_atom(v),
    do: v |> Atom.to_string() |> convert_snake_case_to_dash_case()

  def to_css(v, "will-change") when is_atom(v),
    do: v |> Atom.to_string() |> convert_snake_case_to_dash_case()

  def to_css(v, _property) when is_atom(v), do: Atom.to_string(v)

  def to_css(v, _property), do: to_string(v)

  @doc """
  Normalizes a CSS value string.

  Applies StyleX's normalize-value.js pipeline:
  - Normalize whitespace
  - Normalize timings (500ms -> .5s)
  - Remove leading zeros (0.5 -> .5)
  - Normalize zero dimensions (0px -> 0)
  - Normalize empty string quotes ('' -> "")
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(value) when is_binary(value) do
    value
    |> normalize_whitespace()
    |> normalize_timings()
    |> normalize_leading_zeros()
    |> normalize_zero_dimensions()
    |> normalize_empty_quotes()
  end

  def normalize(value), do: to_string(value)

  @doc """
  Converts an Elixir property key to CSS property name.

  ## Examples

      iex> LiveStyle.Value.to_css_property(:background_color)
      "background-color"

      iex> LiveStyle.Value.to_css_property("margin-top")
      "margin-top"
  """
  @spec to_css_property(atom() | String.t()) :: String.t()
  def to_css_property(key) when is_atom(key) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end

  def to_css_property(key), do: to_string(key)

  # Round number to 4 decimal places
  defp round_number(v) when is_integer(v), do: Integer.to_string(v)

  defp round_number(v) when is_float(v) do
    rounded = Float.round(v * 10_000) / 10_000

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      :erlang.float_to_binary(rounded, decimals: 4)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    end
  end

  # Get unit suffix for numeric values
  # Delegates to Property module for centralized compile-time lookups
  defp get_number_suffix(property), do: Property.unit_suffix(property)

  # Convert px value to rem for font-size when enabled
  defp px_to_rem(px_value) do
    root_px = LiveStyle.Config.font_size_root_px()
    rem_value = px_value / root_px

    # Format the rem value, removing trailing zeros
    formatted =
      if rem_value == trunc(rem_value) do
        Integer.to_string(trunc(rem_value))
      else
        :erlang.float_to_binary(Float.round(rem_value, 4), decimals: 4)
        |> String.trim_trailing("0")
        |> String.trim_trailing(".")
      end

    "#{formatted}rem"
  end

  # Quote content and hyphenate-character property values
  # Matching StyleX's transform-value.js behavior

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

  # Check if value contains a CSS function
  defp contains_css_function?(val) do
    Enum.any?(@css_function_patterns, &String.contains?(val, &1))
  end

  # Check if value has matching quotes (at least 2 of the same quote character)
  defp has_matching_quotes?(val) do
    count_char(val, ?") >= 2 or count_char(val, ?') >= 2
  end

  defp count_char(string, char) do
    string |> :binary.matches(<<char>>) |> length()
  end

  defp quote_content_value(value) do
    val = String.trim(value)
    if skip_quoting_content?(val), do: val, else: "\"#{val}\""
  end

  defp skip_quoting_content?(val) do
    contains_css_function?(val) or content_keyword?(val) or has_matching_quotes?(val)
  end

  # Quote hyphenate-character property values
  # Valid values: auto | <string>
  # "auto" is a keyword that shouldn't be quoted, everything else should be
  defp quote_hyphenate_character_value(value) do
    val = String.trim(value)
    if skip_quoting_hyphenate?(val), do: val, else: "\"#{val}\""
  end

  defp skip_quoting_hyphenate?(val) do
    hyphenate_keyword?(val) or has_matching_quotes?(val)
  end

  # Convert snake_case to dash-case for transition-property and will-change values
  # e.g., "background_color" -> "background-color"
  # Skips custom properties (starting with --)
  defp convert_snake_case_to_dash_case(value) do
    # Handle comma-separated values (e.g., "opacity, background_color")
    value
    |> String.split(",")
    |> Enum.map_join(",", fn part ->
      part = String.trim(part)

      # Don't convert custom properties
      case part do
        <<"--", _rest::binary>> -> part
        _ -> String.replace(part, "_", "-")
      end
    end)
  end

  # Normalize whitespace (matching StyleX's whitespace.js)
  # - Trim leading/trailing spaces
  # - Multiple spaces → single space
  # - Remove spaces around commas: `a , b` → `a,b`
  # - Remove spaces around function parentheses: `fn( x )` → `fn(x)`
  # - Remove space before !important
  defp normalize_whitespace(value) do
    value
    |> String.trim()
    |> String.replace(@whitespace_comma_regex, ",")
    |> String.replace(@multiple_spaces_regex, " ")
    |> normalize_function_whitespace()
    |> String.replace(@important_space_regex, "!important")
  end

  # Remove spaces after opening paren and before closing paren in functions
  # e.g., "rgb( 255 , 0 , 0 )" -> "rgb(255,0,0)"
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
  # StyleX behavior:
  # - 0deg/0grad/0turn/0rad -> 0deg (angles need consistent unit)
  # - 0ms/0s -> 0s (timings need consistent unit)
  # - 0fr -> 0fr (fractions must keep unit - NOT in length regex, so preserved)
  # - 0% -> 0% (percentages must keep unit - NOT in length regex, so preserved)
  # - 0px/0em/etc -> 0 (lengths can drop unit, but only outside functions)
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

  defp normalize_zero_angle(value) do
    Regex.replace(@zero_angle_regex, value, "0deg")
  end

  defp normalize_zero_timing(value) do
    Regex.replace(@zero_timing_regex, value, "0s")
  end

  defp normalize_zero_length(value) do
    Regex.replace(@zero_length_regex, value, "0")
  end

  defp normalize_zero_length_careful(value) do
    Regex.replace(@zero_length_careful_regex, value, "0")
  end

  # StyleX: Make empty strings use consistent double quotes
  # '' -> ""
  defp normalize_empty_quotes(value) do
    String.replace(value, "''", "\"\"")
  end
end
