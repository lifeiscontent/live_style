defmodule LiveStyle.Class.Conditional do
  @moduledoc false
  # Internal module for conditional value detection and flattening.
  #
  # A value is "conditional" if it represents a list of selector-value pairs,
  # like `[{:default, "red"}, {":hover", "blue"}]`.
  #
  # Detection rules:
  # 1. Has `:default` or `"default"` key → conditional
  # 2. All keys are selector strings (start with ":" or "@") → conditional
  # 3. Otherwise → not conditional
  #
  # Note: All conditional values should be sorted lists at this point.
  # Maps are converted to sorted lists at storage time.
  #
  # Special handling for @starting-style:
  # When inside @starting-style with responsive variants, default must become
  # an inverse media query. Unlike regular CSS where specificity resolves conflicts,
  # @starting-style applies ALL matching rules at element insertion, so an
  # unconditional default would "leak" to all viewports.

  @doc false
  @spec conditional?(term()) :: boolean()
  def conditional?(value) when is_list(value) do
    case extract_keys(value) do
      {:ok, keys} -> has_default?(keys) or all_selector_keys?(keys)
      :error -> false
    end
  end

  def conditional?(_), do: false

  defp extract_keys(list) do
    keys =
      Enum.map(list, fn
        {key, _value} when is_atom(key) or is_binary(key) -> key
        _ -> throw(:not_key_value_list)
      end)

    {:ok, keys}
  catch
    :not_key_value_list -> :error
  end

  defp has_default?(keys) do
    :default in keys or "default" in keys
  end

  defp all_selector_keys?([]), do: false

  defp all_selector_keys?(keys) do
    Enum.all?(keys, &selector_key?/1)
  end

  @doc false
  @spec flatten(term(), String.t() | nil) :: [{String.t() | nil, term()}]
  # Conditional values are sorted lists at this point
  def flatten(value_list, parent_selector) when is_list(value_list) do
    if conditional?(value_list) do
      # Transform default to inverse media query when inside @starting-style
      # with responsive variants (see module doc for explanation)
      transformed = maybe_transform_starting_style_default(value_list, parent_selector)
      Enum.flat_map(transformed, &flatten_entry(&1, parent_selector))
    else
      [{parent_selector, value_list}]
    end
  end

  def flatten(value, parent_selector) do
    [{parent_selector, value}]
  end

  defp flatten_entry({condition, value}, parent_selector) do
    current_selector = combine_selectors(parent_selector, condition)

    if is_list(value) and conditional?(value) do
      flatten(value, current_selector)
    else
      [{current_selector, value}]
    end
  end

  @doc false
  @spec combine_selectors(String.t() | nil, atom() | String.t()) :: String.t() | nil
  def combine_selectors(nil, key) when key in [:default, "default"], do: nil
  def combine_selectors(parent, key) when key in [:default, "default"], do: parent

  def combine_selectors(nil, condition) when is_atom(condition) do
    to_string(condition)
  end

  def combine_selectors(nil, condition) when is_binary(condition), do: condition

  def combine_selectors(parent, condition) when is_atom(condition) do
    parent <> to_string(condition)
  end

  def combine_selectors(parent, condition) when is_binary(condition) do
    parent <> condition
  end

  @doc false
  @spec selector_key?(atom() | String.t()) :: boolean()
  def selector_key?(key) when is_atom(key), do: selector_key?(Atom.to_string(key))
  def selector_key?(<<":", _rest::binary>>), do: true
  def selector_key?(<<"@", _rest::binary>>), do: true
  def selector_key?(_), do: false

  # Transform default to inverse media query when inside @starting-style
  # with responsive variants. This prevents the default from "leaking" to
  # all viewports (see module doc for detailed explanation).
  defp maybe_transform_starting_style_default(value_list, parent_selector) do
    if inside_starting_style?(parent_selector) and has_responsive_variants?(value_list) do
      transform_default_to_inverse_media(value_list)
    else
      value_list
    end
  end

  defp inside_starting_style?(nil), do: false
  defp inside_starting_style?(selector), do: String.contains?(selector, "@starting-style")

  defp has_responsive_variants?(value_list) do
    Enum.any?(value_list, fn
      {key, _} when is_binary(key) -> String.starts_with?(key, "@media")
      {key, _} when is_atom(key) -> String.starts_with?(Atom.to_string(key), "@media")
      _ -> false
    end)
  end

  defp transform_default_to_inverse_media(value_list) do
    # Extract all min-width breakpoints from @media queries
    breakpoints = extract_min_width_breakpoints(value_list)

    if Enum.empty?(breakpoints) do
      # No min-width queries, check for max-width
      max_breakpoints = extract_max_width_breakpoints(value_list)

      if Enum.empty?(max_breakpoints) do
        # No recognizable breakpoints, leave unchanged
        value_list
      else
        # Has max-width queries - default should be min-width of largest + epsilon
        max_bp = Enum.max(max_breakpoints)
        inverse = "@media (min-width: #{format_breakpoint(max_bp + 0.01)})"
        replace_default_with_media(value_list, inverse)
      end
    else
      # Has min-width queries - default should be max-width of smallest - epsilon
      min_bp = Enum.min(breakpoints)
      inverse = "@media (max-width: #{format_breakpoint(min_bp - 0.01)})"
      replace_default_with_media(value_list, inverse)
    end
  end

  defp extract_min_width_breakpoints(value_list) do
    value_list
    |> Enum.flat_map(fn
      {key, _} ->
        key_str = if is_atom(key), do: Atom.to_string(key), else: key

        case Regex.run(~r/@media\s*\(\s*min-width:\s*([\d.]+)(px)?\s*\)/, key_str) do
          [_, value | _] -> [parse_breakpoint(value)]
          _ -> []
        end

      _ ->
        []
    end)
  end

  defp extract_max_width_breakpoints(value_list) do
    value_list
    |> Enum.flat_map(fn
      {key, _} ->
        key_str = if is_atom(key), do: Atom.to_string(key), else: key

        case Regex.run(~r/@media\s*\(\s*max-width:\s*([\d.]+)(px)?\s*\)/, key_str) do
          [_, value | _] -> [parse_breakpoint(value)]
          _ -> []
        end

      _ ->
        []
    end)
  end

  defp parse_breakpoint(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp format_breakpoint(value) when is_float(value) do
    # Format with minimal decimal places
    if value == trunc(value) do
      "#{trunc(value)}px"
    else
      "#{:erlang.float_to_binary(value, decimals: 2)}px"
    end
  end

  defp replace_default_with_media(value_list, media_query) do
    Enum.map(value_list, fn
      {key, value} when key in [:default, "default"] -> {media_query, value}
      entry -> entry
    end)
  end
end
