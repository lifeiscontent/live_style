defmodule LiveStyle.CSSValue do
  @moduledoc """
  CSS value normalization and transformation.

  Follows StyleX's transform-value.js and normalize-value.js approach.

  Delegates property checks to `LiveStyle.Property` for centralized
  compile-time generated lookups.
  Regex patterns are compiled at module level for efficiency.
  """

  alias LiveStyle.CSSValue.Normalize
  alias LiveStyle.CSSValue.Number
  alias LiveStyle.CSSValue.Quote

  @doc false
  @spec css_var_expr?(term()) :: boolean()
  def css_var_expr?(value) when is_binary(value) do
    String.starts_with?(value, "var(") and String.ends_with?(value, ")")
  end

  def css_var_expr?(_), do: false

  @doc """
  Converts a value to its CSS string representation.

  ## Examples

      iex> LiveStyle.CSSValue.to_css(10, "padding")
      "10px"

      iex> LiveStyle.CSSValue.to_css(0.5, "opacity")
      "0.5"

      iex> LiveStyle.CSSValue.to_css("0.5s", "transition-duration")
      ".5s"
  """
  @spec to_css(any(), String.t() | nil) :: String.t()
  def to_css(v, property) when is_number(v), do: Number.to_css(v, property)

  # content needs special quoting handling
  def to_css(v, "content") when is_binary(v),
    do: v |> Normalize.normalize() |> Quote.quote_content()

  # hyphenate-character needs special quoting handling
  # but "auto" is a valid keyword that shouldn't be quoted
  def to_css(v, "hyphenate-character") when is_binary(v),
    do: v |> Normalize.normalize() |> Quote.quote_hyphenate_character()

  # For transition-property and will-change, convert snake_case strings to dash-case
  # e.g., "background_color" -> "background-color"
  # This is the Elixir idiom equivalent of StyleX's camelCase -> kebab-case
  def to_css(v, "transition-property") when is_binary(v),
    do: v |> Normalize.normalize() |> convert_snake_case_to_dash_case()

  def to_css(v, "will-change") when is_binary(v),
    do: v |> Normalize.normalize() |> convert_snake_case_to_dash_case()

  def to_css(v, _property) when is_binary(v), do: Normalize.normalize(v)

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

  def to_css(v, _property) when is_tuple(v) do
    raise ArgumentError,
          "Invalid property value: tuple values are not supported. " <>
            "Use a conditional map/keyword list for selectors (e.g. %{:default => ..., ':hover' => ...}) " <>
            "or a string/number value for plain properties."
  end

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
  def normalize(value) when is_binary(value), do: Normalize.normalize(value)

  def normalize(value), do: to_string(value)

  @doc """
  Converts an Elixir property key to CSS property name.

  ## Examples

      iex> LiveStyle.CSSValue.to_css_property(:background_color)
      "background-color"

      iex> LiveStyle.CSSValue.to_css_property("margin-top")
      "margin-top"
  """
  @spec to_css_property(atom() | String.t()) :: String.t()
  def to_css_property(key) when is_atom(key) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end

  def to_css_property(key) do
    key
    |> to_string()
    |> unwrap_var_as_property_name()
  end

  # If someone uses a CSS var reference as a *property key* (StyleX-style),
  # unwrap `var(--token)` into `--token`.
  #
  # This allows:
  #
  #   class :parent, %{var({Tokens, :childColor}) => "red"}
  #
  # to generate:
  #
  #   .x123{--vabc:red}
  defp unwrap_var_as_property_name("var(" <> _rest = prop) do
    inner = prop |> String.trim_leading("var(") |> String.trim_trailing(")")

    cond do
      # Only unwrap the simple form `var(--name)`.
      String.contains?(inner, ",") ->
        prop

      String.starts_with?(inner, "--") ->
        inner

      true ->
        prop
    end
  end

  defp unwrap_var_as_property_name(prop), do: prop

  defp convert_snake_case_to_dash_case(value) do
    value
    |> String.split(",")
    |> Enum.map_join(",", fn part ->
      part = String.trim(part)

      case part do
        <<"--", _rest::binary>> -> part
        _ -> String.replace(part, "_", "-")
      end
    end)
  end
end
