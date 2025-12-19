defmodule LiveStyle.Fallback do
  @moduledoc false
  # Internal module for CSS fallback value processing.
  # Implements StyleX-compatible fallback value handling.

  alias LiveStyle.Class.CSS, as: ClassCss
  alias LiveStyle.Hash
  alias LiveStyle.Priority
  alias LiveStyle.Value

  @doc false
  @spec process_array(String.t(), list()) :: {String.t(), map()}
  def process_array(css_prop, values) do
    # StyleX validation: array values can only contain strings or numbers
    validate_array_values!(values)

    normalized_values =
      values
      |> Enum.map(&Value.to_css(&1, css_prop))

    # Apply variableFallbacks transformation (nest vars, preserve order)
    transformed = variable_fallbacks(normalized_values)

    # StyleX joins array values with ", " for hashing
    hash_value = Enum.join(normalized_values, ", ")
    class_name = Hash.atomic_class(css_prop, hash_value, nil, nil, nil)

    # Generate StyleX-compatible metadata
    {ltr_css, rtl_css} =
      ClassCss.generate_metadata(class_name, css_prop, transformed, nil, nil)

    priority = Priority.calculate(css_prop, nil, nil)

    build_result(css_prop, class_name, transformed, ltr_css, rtl_css, priority)
  end

  @doc false
  @spec process_first_that_works(String.t(), list()) :: {String.t(), map()}
  def process_first_that_works(css_prop, values) do
    normalized_values =
      values
      |> Enum.map(&Value.to_css(&1, css_prop))

    # Apply firstThatWorks transformation (reverse + nest vars)
    transformed = first_that_works_transform(normalized_values)

    # StyleX joins array values with ", " for hashing
    hash_value = Enum.join(normalized_values, ", ")
    class_name = Hash.atomic_class(css_prop, hash_value, nil, nil, nil)

    # Generate StyleX-compatible metadata
    {ltr_css, rtl_css} =
      ClassCss.generate_metadata(class_name, css_prop, transformed, nil, nil)

    priority = Priority.calculate(css_prop, nil, nil)

    build_result(css_prop, class_name, transformed, ltr_css, rtl_css, priority)
  end

  @spec build_result(
          String.t(),
          String.t(),
          list(),
          String.t(),
          String.t() | nil,
          non_neg_integer()
        ) ::
          {String.t(), map()}
  defp build_result(css_prop, class_name, transformed, ltr_css, rtl_css, priority) do
    result_value =
      case transformed do
        [single] -> single
        multiple -> List.first(multiple)
      end

    base_result = %{
      class: class_name,
      value: result_value,
      ltr: ltr_css,
      rtl: rtl_css,
      priority: priority
    }

    # Only include fallback_values if we have multiple CSS declarations
    result =
      case transformed do
        [_single] -> base_result
        multiple -> Map.put(base_result, :fallback_values, multiple)
      end

    {css_prop, result}
  end

  @spec css_var?(term()) :: boolean()
  defp css_var?(value) when is_binary(value) do
    String.starts_with?(value, "var(") and String.ends_with?(value, ")")
  end

  defp css_var?(_), do: false

  @spec extract_var_name(String.t()) :: String.t()
  defp extract_var_name(value) do
    value
    |> String.trim_leading("var(")
    |> String.trim_trailing(")")
  end

  # StyleX validation: array values can only contain strings or numbers
  # Matches validation-stylex-create-test.js: "A style array value can only contain strings or numbers."
  defp validate_array_values!(values) do
    Enum.each(values, fn value ->
      unless valid_array_value?(value) do
        raise ArgumentError,
              "A style array value can only contain strings or numbers, got: #{inspect(value)}"
      end
    end)
  end

  defp valid_array_value?(value) when is_binary(value), do: true
  defp valid_array_value?(value) when is_number(value), do: true
  defp valid_array_value?(value) when is_atom(value) and value not in [true, false, nil], do: true
  defp valid_array_value?(_), do: false

  # StyleX variableFallbacks - used for plain arrays
  # Nests vars only when non-var values come BEFORE the first var
  # Matches convert-to-className.js variableFallbacks function
  defp variable_fallbacks(values) do
    if Enum.any?(values, &css_var?/1) do
      process_values_with_vars(values)
    else
      # No vars - return as-is (order preserved)
      values
    end
  end

  defp process_values_with_vars(values) do
    first_var = Enum.find_index(values, &css_var?/1)
    last_var = find_last_index(values, &css_var?/1)

    values_before = Enum.slice(values, 0, first_var)
    var_values = Enum.slice(values, first_var, last_var - first_var + 1)
    values_after = Enum.slice(values, last_var + 1, length(values) - last_var - 1)

    # Extract var names (unwrap var(--x) to --x)
    var_names = extract_var_names(var_values)

    nested = build_nested_vars(values_before, var_names)
    nested ++ values_after
  end

  defp extract_var_names(var_values) do
    var_values
    |> Enum.reverse()
    |> Enum.map(fn val ->
      if css_var?(val), do: extract_var_name(val), else: val
    end)
  end

  defp build_nested_vars([], var_names) do
    # No values before first var - just compose vars (no nesting with after values)
    [compose_vars(var_names)]
  end

  defp build_nested_vars(values_before, var_names) do
    # Values before first var get nested with the vars
    # compose_vars expects innermost first, so val goes at the beginning
    Enum.map(values_before, fn val -> compose_vars([val | var_names]) end)
  end

  # StyleX firstThatWorks transformation
  # Nests vars when var comes FIRST, otherwise keeps separate declarations
  # Matches stylex-first-that-works.js
  defp first_that_works_transform(values) do
    case Enum.find_index(values, &css_var?/1) do
      nil -> Enum.reverse(values)
      0 -> transform_var_first(values)
      idx -> transform_non_var_first(values, idx)
    end
  end

  defp transform_var_first(values) do
    composed = compose_var_parts(extract_var_parts(values, 0))
    [composed]
  end

  defp transform_non_var_first(values, idx) do
    priorities = values |> Enum.take(idx) |> Enum.reverse()
    rest = Enum.drop(values, idx)
    composed = compose_var_parts(extract_var_parts(rest, 0))
    [composed | priorities]
  end

  defp extract_var_parts(values, offset) do
    first_non_var = Enum.find_index(values, &(not css_var?(&1)))
    end_idx = if first_non_var, do: first_non_var + 1, else: length(values)
    Enum.slice(values, offset, end_idx)
  end

  defp compose_var_parts(var_parts) do
    var_parts
    |> Enum.reverse()
    |> Enum.map(&extract_var_or_value/1)
    |> compose_vars()
  end

  defp extract_var_or_value(val) do
    if css_var?(val), do: extract_var_name(val), else: val
  end

  # Find last index matching predicate (returns -1 if not found)
  defp find_last_index(list, pred) do
    list
    |> Enum.with_index()
    |> Enum.reduce(-1, fn {val, idx}, acc -> if pred.(val), do: idx, else: acc end)
  end

  # Compose CSS variables using StyleX's reduce pattern
  # Input: ["fallback", "--b", "--a"] (reversed - innermost first)
  # Output: "var(--a, var(--b, fallback))"
  #
  # The reduce wraps previous result inside current var:
  # "" + "fallback" → "fallback"
  # "fallback" + "--b" → "var(--b, fallback)"
  # "var(--b, fallback)" + "--a" → "var(--a, var(--b, fallback))"
  defp compose_vars(vars) do
    Enum.reduce(vars, "", fn var_name, so_far ->
      cond do
        so_far == "" and String.starts_with?(var_name, "--") ->
          "var(#{var_name})"

        so_far == "" ->
          # Non-var as innermost fallback
          var_name

        String.starts_with?(var_name, "--") ->
          # Wrap so_far inside this var
          "var(#{var_name},#{so_far})"

        true ->
          # Non-var after first element - shouldn't happen in valid input
          # But if it does, just return as-is
          so_far
      end
    end)
  end
end
