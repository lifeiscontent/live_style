defmodule LiveStyle.MediaQuery.Transform do
  @moduledoc """
  Implements StyleX's `lastMediaQueryWinsTransform` algorithm.

  This transforms media queries so that later queries win over earlier ones
  by adding upper bounds to earlier min-width queries and lower bounds to
  earlier max-width queries.

  Example transformation for min-width queries:
    default: 'red'
    '@media (min-width: 1000px)': 'blue'
    '@media (min-width: 2000px)': 'purple'

  Becomes:
    default: 'red'
    '@media (min-width: 1000px) and (max-width: 1999.99px)': 'blue'
    '@media (min-width: 2000px)': 'purple'

  Example transformation for max-width queries:
    default: 'red'
    '@media (max-width: 900px)': 'blue'
    '@media (max-width: 500px)': 'purple'

  Becomes:
    default: 'red'
    '@media (min-width: 500.01px) and (max-width: 900px)': 'blue'
    '@media (max-width: 500px)': 'purple'

  Regex patterns compiled at module level for efficiency.
  """

  # Compile regex patterns at module level
  @min_width_regex ~r/@media\s*\(min-width:\s*(\d+(?:\.\d+)?)(px|em|rem)\)/
  @max_width_regex ~r/@media\s*\(max-width:\s*(\d+(?:\.\d+)?)(px|em|rem)\)/

  @doc """
  Transform a conditional value map to implement "last media query wins" semantics.

  Takes a map like:
    %{
      default: "red",
      "@media (min-width: 1000px)": "blue",
      "@media (min-width: 2000px)": "purple"
    }

  And returns:
    %{
      default: "red",
      "@media (min-width: 1000px) and (max-width: 1999.99px)": "blue",
      "@media (min-width: 2000px)": "purple"
    }
  """
  def transform(value_map) when is_map(value_map) do
    # Extract media query keys
    media_keys = for key <- Map.keys(value_map), media_query_key?(key), do: to_string(key)

    # If less than 2 media queries, no transformation needed
    if length(media_keys) < 2 do
      value_map
    else
      transform_media_queries(value_map, media_keys)
    end
  end

  def transform(value_list) when is_list(value_list) do
    # Convert to map, transform, convert back
    value_list
    |> Map.new()
    |> transform()
    |> Enum.to_list()
  end

  def transform(other), do: other

  defp media_query_key?(key) when is_atom(key) do
    media_query_key?(Atom.to_string(key))
  end

  defp media_query_key?(<<"@media ", _rest::binary>>), do: true
  defp media_query_key?(key) when is_binary(key), do: false

  defp media_query_key?(_), do: false

  defp transform_media_queries(value_map, media_keys) do
    # Parse all media queries
    parsed =
      media_keys
      |> Enum.map(fn key ->
        {key, parse_media_query(key)}
      end)

    # Group by dimension (width/height)
    # For simplicity, we'll handle the common case of width-based queries
    width_queries =
      parsed
      |> Enum.filter(fn {_key, parsed} ->
        parsed != nil and (parsed.type == :min_width or parsed.type == :max_width)
      end)
      |> Enum.sort_by(fn {_key, parsed} -> parsed.value end)

    # Build transformations
    transformations = build_transformations(width_queries)

    # Apply transformations to the value map
    Enum.reduce(transformations, value_map, fn {old_key, new_key}, acc ->
      apply_transformation(acc, old_key, new_key)
    end)
  end

  defp apply_transformation(acc, old_key, old_key), do: acc

  defp apply_transformation(acc, old_key, new_key) do
    cond do
      Map.has_key?(acc, old_key) ->
        replace_key(acc, old_key, new_key)

      # Try to find atom key without creating new atoms
      # Use String.to_existing_atom to avoid atom table exhaustion
      (atom_key = safe_to_existing_atom(old_key)) && Map.has_key?(acc, atom_key) ->
        replace_key(acc, atom_key, new_key)

      true ->
        acc
    end
  end

  # Safely convert string to existing atom, returns nil if atom doesn't exist
  defp safe_to_existing_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end

  defp replace_key(acc, old_key, new_key) do
    value = Map.get(acc, old_key)

    acc
    |> Map.delete(old_key)
    |> Map.put(new_key, value)
  end

  defp parse_media_query(query) do
    # Parse @media (min-width: 1000px) or @media (max-width: 900px)
    cond do
      # min-width pattern
      match = Regex.run(@min_width_regex, query) ->
        [_, value_str, unit] = match
        value = parse_number(value_str)
        %{type: :min_width, value: value, unit: unit, original: query}

      # max-width pattern
      match = Regex.run(@max_width_regex, query) ->
        [_, value_str, unit] = match
        value = parse_number(value_str)
        %{type: :max_width, value: value, unit: unit, original: query}

      true ->
        nil
    end
  end

  defp parse_number(str) do
    if String.contains?(str, ".") do
      String.to_float(str)
    else
      String.to_integer(str)
    end
  end

  defp build_transformations(width_queries) do
    # Group by type (min-width vs max-width)
    {min_queries, max_queries} =
      Enum.split_with(width_queries, fn {_key, parsed} ->
        parsed.type == :min_width
      end)

    min_transformations = build_min_width_transformations(min_queries)
    max_transformations = build_max_width_transformations(max_queries)

    min_transformations ++ max_transformations
  end

  # For min-width queries, add max-width upper bounds
  # @media (min-width: 1000px) becomes @media (min-width: 1000px) and (max-width: 1999.99px)
  # when there's also @media (min-width: 2000px)
  defp build_min_width_transformations(queries) when length(queries) < 2, do: []

  defp build_min_width_transformations(queries) do
    # Sort by value ascending
    sorted = Enum.sort_by(queries, fn {_key, parsed} -> parsed.value end)

    sorted
    |> Enum.with_index()
    |> Enum.map(fn {{old_key, parsed}, index} ->
      if index < length(sorted) - 1 do
        # Not the last query - add upper bound
        {_next_key, next_parsed} = Enum.at(sorted, index + 1)
        upper_bound = next_parsed.value - 0.01

        new_key =
          "@media (min-width: #{format_value(parsed.value)}#{parsed.unit}) and (max-width: #{format_value(upper_bound)}#{parsed.unit})"

        {old_key, new_key}
      else
        # Last query - no transformation
        {old_key, old_key}
      end
    end)
  end

  # For max-width queries, add min-width lower bounds
  # @media (max-width: 900px) becomes @media (min-width: 500.01px) and (max-width: 900px)
  # when there's also @media (max-width: 500px)
  defp build_max_width_transformations(queries) when length(queries) < 2, do: []

  defp build_max_width_transformations(queries) do
    # Sort by value descending (largest first)
    sorted = Enum.sort_by(queries, fn {_key, parsed} -> -parsed.value end)

    sorted
    |> Enum.with_index()
    |> Enum.map(fn {{old_key, parsed}, index} ->
      if index < length(sorted) - 1 do
        # Not the last query - add lower bound
        {_next_key, next_parsed} = Enum.at(sorted, index + 1)
        lower_bound = next_parsed.value + 0.01

        new_key =
          "@media (min-width: #{format_value(lower_bound)}#{parsed.unit}) and (max-width: #{format_value(parsed.value)}#{parsed.unit})"

        {old_key, new_key}
      else
        # Last query - no transformation
        {old_key, old_key}
      end
    end)
  end

  defp format_value(value) when is_integer(value), do: Integer.to_string(value)

  defp format_value(value) when is_float(value) do
    # Format with up to 2 decimal places, removing trailing zeros
    formatted = :erlang.float_to_binary(value, decimals: 2)

    formatted
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end
end
