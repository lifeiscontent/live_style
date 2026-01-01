defmodule LiveStyle.Compiler.Class.Fallback do
  @moduledoc false
  # Internal module for CSS fallback value processing.
  # Implements StyleX-compatible fallback value handling.

  alias LiveStyle.Compiler.CSS.AtomicClass
  alias LiveStyle.Compiler.CSS.Priority
  alias LiveStyle.{CSSValue, Hash}

  @doc false
  @spec process_array(String.t(), list()) :: {String.t(), map()}
  def process_array(css_prop, values) do
    # StyleX validation: array values can only contain strings or numbers
    validate_array_values!(values)

    normalized_values =
      values
      |> Enum.map(&CSSValue.to_css(&1, css_prop))

    # Apply variableFallbacks transformation (nest vars, preserve order)
    transformed = variable_fallbacks(normalized_values)

    # StyleX joins array values with ", " for hashing
    hash_value = Enum.join(normalized_values, ", ")
    class_name = Hash.atomic_class(css_prop, hash_value, nil, nil, nil)

    # Generate StyleX-compatible metadata
    {ltr_css, rtl_css} =
      AtomicClass.generate_metadata(class_name, css_prop, transformed, nil, nil)

    priority = Priority.calculate(css_prop, nil, nil)

    build_result(css_prop, class_name, transformed, ltr_css, rtl_css, priority)
  end

  @doc false
  @spec process_fallback(String.t(), list()) :: {String.t(), map()}
  def process_fallback(css_prop, values) do
    normalized_values =
      values
      |> Enum.map(&CSSValue.to_css(&1, css_prop))

    # Apply firstThatWorks transformation (reverse + nest vars)
    transformed = fallback_transform(normalized_values)

    # StyleX joins array values with ", " for hashing
    hash_value = Enum.join(normalized_values, ", ")
    class_name = Hash.atomic_class(css_prop, hash_value, nil, nil, nil)

    # Generate StyleX-compatible metadata
    {ltr_css, rtl_css} =
      AtomicClass.generate_metadata(class_name, css_prop, transformed, nil, nil)

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
  defp build_result(css_prop, class_name, [single], ltr_css, rtl_css, priority) do
    result = %{
      class: class_name,
      value: single,
      ltr: ltr_css,
      rtl: rtl_css,
      priority: priority
    }

    {css_prop, result}
  end

  defp build_result(css_prop, class_name, [first | _] = multiple, ltr_css, rtl_css, priority) do
    result = %{
      class: class_name,
      value: first,
      ltr: ltr_css,
      rtl: rtl_css,
      priority: priority,
      fallback_values: multiple
    }

    {css_prop, result}
  end

  @spec css_var?(term()) :: boolean()
  defp css_var?(value), do: CSSValue.css_var_expr?(value)

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

    # Keep var() expressions intact; we only "unwrap" by inserting fallbacks
    # (i.e. `var(--x)` becomes `var(--x, fallback)` when needed).
    var_exprs = Enum.reverse(var_values)

    nested = build_nested_vars(values_before, var_exprs)
    nested ++ values_after
  end

  defp build_nested_vars([], var_exprs) do
    # No values before first var - just compose vars (no nesting with after values)
    [compose_vars(var_exprs)]
  end

  defp build_nested_vars(values_before, var_exprs) do
    # Values before first var get nested with the vars
    # compose_vars expects innermost first, so val goes at the beginning
    Enum.map(values_before, fn val -> compose_vars([val | var_exprs]) end)
  end

  # StyleX firstThatWorks transformation
  # Nests vars when var comes FIRST, otherwise keeps separate declarations
  # Matches stylex-first-that-works.js
  defp fallback_transform(values) do
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
    |> compose_vars()
  end

  defp find_last_index(list, pred), do: LiveStyle.Utils.find_last_index(list, pred)

  # Compose CSS variables using StyleX's reduce pattern.
  #
  # We keep `var(...)` expressions intact and only add fallbacks when nesting.
  #
  # Input: ["fallback", "var(--b)", "var(--a)"] (reversed - innermost first)
  # Output: "var(--a,var(--b,fallback))"
  defp compose_vars(vars) do
    Enum.reduce(vars, "", fn value, so_far ->
      cond do
        so_far == "" and css_var?(value) ->
          value

        so_far == "" ->
          # Non-var as innermost fallback
          value

        css_var?(value) ->
          # Turn `var(--x)` into `var(--x,so_far)`
          String.trim_trailing(value, ")") <> ",#{so_far})"

        true ->
          # Non-var after first element - shouldn't happen in valid input
          so_far
      end
    end)
  end
end
