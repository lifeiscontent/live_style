defmodule LiveStyle.Data.Parser do
  @moduledoc """
  Parses data files for LiveStyle configuration.

  Uses compile-time data loading with `@external_resource` tracking
  for automatic recompilation when data files change.

  Inspired by the unicode library's approach to data parsing.

  ## Note on String.to_atom Usage

  This module uses `String.to_atom/1` in several places. This is safe because:
  1. It runs only at **compile time**, not at runtime
  2. The input comes from **static data files** bundled with the library
  3. The set of atoms is **finite and bounded** by the data files
  4. No user input ever reaches these functions

  The atoms are category names, function names, and type identifiers that are
  known at compile time and used for pattern matching in generated code.
  """

  # Get the data directory path at compile time
  # __DIR__ is lib/live_style/data, so we go up three levels to reach the project root
  @data_dir Path.expand("../../../data", __DIR__)

  @doc """
  Returns the path to the data directory.
  """
  def data_dir, do: @data_dir

  @doc """
  Returns the full path to a data file.
  """
  def data_path(filename), do: Path.join(@data_dir, filename)

  # Reads a data file and returns non-empty, non-comment lines
  # Uses binary pattern matching for efficient comment detection (like unicode library)
  defp read_data_lines(filename) do
    filename
    |> data_path()
    |> File.stream!()
    |> Stream.reject(&comment_or_empty?/1)
    |> Stream.map(&String.trim_trailing(&1, "\n"))
    |> Enum.to_list()
  end

  # Returns true if line is a comment (starts with #) or empty/whitespace only
  # Uses binary pattern matching for efficiency (like unicode library)
  defp comment_or_empty?(<<"\n">>), do: true
  defp comment_or_empty?(<<"\r\n">>), do: true
  defp comment_or_empty?(<<"#", _rest::binary>>), do: true
  defp comment_or_empty?(<<" ", rest::binary>>), do: comment_or_empty?(rest)
  defp comment_or_empty?(<<"\t", rest::binary>>), do: comment_or_empty?(rest)
  defp comment_or_empty?(<<>>), do: true
  defp comment_or_empty?(_), do: false

  # Converts CSS kebab-case to Elixir snake_case atom
  # Used for internal category names loaded from data files at compile time
  defp css_to_atom(css_string) do
    css_string
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  @doc """
  Parses property priorities from data file.
  Returns a map of CSS property names to category atoms.

  Category names use kebab-case in the data file and are converted
  to snake_case atoms during parsing.
  """
  def property_priorities do
    "property_priorities.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [property, category] = String.split(line, ";", parts: 2)
      # Convert kebab-case category to snake_case atom
      {String.trim(property), css_to_atom(String.trim(category))}
    end)
    |> Map.new()
  end

  @doc """
  Parses pseudo-class priorities from data file.
  Returns a map of pseudo-class selectors to priority numbers.
  """
  def pseudo_priorities do
    "pseudo_priorities.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [pseudo, priority] = String.split(line, ";", parts: 2)
      {String.trim(pseudo), String.to_integer(String.trim(priority))}
    end)
    |> Map.new()
  end

  @doc """
  Parses unitless properties from data file.
  Returns a MapSet of property names (in kebab-case) that don't take units.
  """
  def unitless_properties do
    "unitless_properties.txt"
    |> read_data_lines()
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  @doc """
  Parses time properties from data file.
  Returns a MapSet of property names (in kebab-case) that use time units.
  """
  def time_properties do
    "time_properties.txt"
    |> read_data_lines()
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  @doc """
  Parses logical properties mappings from data file.
  Returns maps for LTR and RTL transformations.
  """
  def logical_properties do
    "logical_properties.txt"
    |> read_data_lines()
    |> Enum.reduce({%{}, %{}}, &parse_logical_property_line/2)
  end

  defp parse_logical_property_line(line, {ltr_acc, rtl_acc}) do
    case String.split(line, ";", parts: 3) do
      [logical, ltr, rtl] ->
        build_logical_property_maps(logical, ltr, rtl, ltr_acc, rtl_acc)

      _ ->
        {ltr_acc, rtl_acc}
    end
  end

  defp build_logical_property_maps(logical, ltr, rtl, ltr_acc, rtl_acc) do
    logical = String.trim(logical)
    ltr_val = String.trim(ltr)
    rtl_val = String.trim(rtl)

    ltr_acc = add_non_empty(ltr_acc, logical, ltr_val)
    rtl_acc = add_non_empty(rtl_acc, logical, rtl_val)

    {ltr_acc, rtl_acc}
  end

  defp add_non_empty(acc, _key, ""), do: acc
  defp add_non_empty(acc, key, val), do: Map.put(acc, key, val)

  @doc """
  Parses logical values mappings from data file.
  Returns maps for LTR and RTL value transformations.
  """
  def logical_values do
    "logical_values.txt"
    |> read_data_lines()
    |> Enum.reduce({%{}, %{}}, fn line, {ltr_acc, rtl_acc} ->
      case String.split(line, ";", parts: 3) do
        [logical, ltr, rtl] ->
          logical = String.trim(logical)
          ltr_val = String.trim(ltr)
          rtl_val = String.trim(rtl)

          ltr_acc = Map.put(ltr_acc, logical, ltr_val)
          rtl_acc = Map.put(rtl_acc, logical, rtl_val)

          {ltr_acc, rtl_acc}

        _ ->
          {ltr_acc, rtl_acc}
      end
    end)
  end

  @doc """
  Parses shorthand expansions from data file.
  Returns a map of CSS property names to expansion function atoms.

  The data file contains pure CSS property relationships:
  - `property` - has its own expansion function
  - `property ; canonical` - is an alias for canonical property

  The code derives function names: `expand_<property>` or `expand_<canonical>`
  """
  def shorthand_properties do
    "shorthand_properties.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      case String.split(line, ";", parts: 2) do
        [property, canonical] ->
          # Alias: use the canonical property's expansion function
          prop = String.trim(property)
          canonical_prop = String.trim(canonical)
          {prop, to_expand_fn(canonical_prop)}

        [property] ->
          # Has its own expansion function
          prop = String.trim(property)
          {prop, to_expand_fn(prop)}
      end
    end)
    |> Map.new()
  end

  # Derives the expansion function name from a property name
  # e.g., "margin-block" -> :expand_margin_block
  defp to_expand_fn(property) do
    ("expand_" <> String.replace(property, "-", "_"))
    |> String.to_atom()
  end

  @doc """
  Parses disallowed shorthands from data file.
  Returns a MapSet of property names disallowed in strict mode.
  """
  def disallowed_shorthands do
    disallowed_shorthands_with_messages()
    |> Map.keys()
    |> MapSet.new()
  end

  @doc """
  Parses disallowed shorthands with their error messages from data file.
  Returns a map of property names to error messages.
  """
  def disallowed_shorthands_with_messages do
    "disallowed_shorthands.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      # Format: property ; error_message
      case String.split(line, ";", parts: 2) do
        [property, message] ->
          {String.trim(property), String.trim(message)}

        [property] ->
          prop = String.trim(property)
          {prop, "'#{prop}' is not supported. Use longhand properties instead."}
      end
    end)
    |> Map.new()
  end

  @doc """
  Parses RTL value properties from data file.
  Returns a MapSet of properties that need value flipping in RTL.
  """
  def rtl_value_properties do
    "rtl_value_properties.txt"
    |> read_data_lines()
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  @doc """
  Parses position-try properties from data file.
  Returns a MapSet of properties allowed in @position-try rules.
  """
  def position_try_properties do
    "position_try_properties.txt"
    |> read_data_lines()
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
  end

  @doc """
  Parses simple expansion definitions from data file.
  Returns a list of {function_name, [{property, value_type}, ...]} tuples.

  Format: source-property ; target-property:value-type, ...

  The data file contains pure CSS property relationships.
  The code derives function names: `expand_<source-property>`
  """
  def keep_shorthands_expansions do
    "keep_shorthands_expansions.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [source_prop, expansions] = String.split(line, ";", parts: 2)
      # Keep source property as CSS string
      css_prop = String.trim(source_prop)

      props =
        expansions
        |> String.split(",")
        |> Enum.map(fn prop_def ->
          [prop, type] = String.split(String.trim(prop_def), ":")
          # Keep property as CSS string, parse type as atom (:value or :nil)
          {String.trim(prop), String.to_atom(String.trim(type))}
        end)

      {css_prop, props}
    end)
    |> Map.new()
  end

  @doc """
  Parses longhand expansion definitions from data file.
  Returns a map of CSS property names to {pattern, [longhand_atoms]} tuples.

  Format: property ; pattern ; longhand-1, longhand-2, ...

  Used to generate both get_longhand_properties/1 and do_expand_to_longhands/4.
  """
  def expand_to_longhands_expansions do
    "expand_to_longhands_expansions.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [property, pattern, longhands] = String.split(line, ";", parts: 3)

      property = String.trim(property)
      pattern = String.to_atom(String.trim(pattern))

      # Keep longhands as CSS strings (e.g., "margin-top")
      longhand_strings =
        longhands
        |> String.split(",")
        |> Enum.map(&String.trim/1)

      {property, {pattern, longhand_strings}}
    end)
    |> Map.new()
  end

  @doc """
  Parses selector expansions from data file.
  Returns a map of standard selectors to their vendor-prefixed variants.

  Format: standard-selector ; variant-1 ; variant-2 ; ...

  Used for cross-browser selector prefixing (e.g., ::placeholder, :fullscreen).
  """
  def selector_expansions do
    "selector_expansions.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [selector | variants] =
        line
        |> String.split(";")
        |> Enum.map(&String.trim/1)

      {selector, variants}
    end)
    |> Map.new()
  end
end
