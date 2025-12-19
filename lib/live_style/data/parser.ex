defmodule LiveStyle.Data.Parser do
  @moduledoc """
  Parses data files for LiveStyle configuration.

  Uses compile-time data loading with `@external_resource` tracking
  for automatic recompilation when data files change.

  Inspired by the unicode library's approach to data parsing.
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

  @doc """
  Parses property priorities from data file.
  Returns a map of CSS property names to category atoms.
  """
  def property_priorities do
    "property_priorities.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [property, category] = String.split(line, ";", parts: 2)
      {String.trim(property), String.to_atom(String.trim(category))}
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
  """
  def shorthand_expansions do
    "shorthand_expansions.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [property, func] = String.split(line, ";", parts: 2)
      {String.trim(property), String.to_atom(String.trim(func))}
    end)
    |> Map.new()
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

  Format: function_name ; prop1:value, prop2:nil, ...
  """
  def simple_expansions do
    "simple_expansions.txt"
    |> read_data_lines()
    |> Enum.map(fn line ->
      [func_name, expansions] = String.split(line, ";", parts: 2)
      func_atom = String.to_atom(String.trim(func_name))

      props =
        expansions
        |> String.split(",")
        |> Enum.map(fn prop_def ->
          [prop, type] = String.split(String.trim(prop_def), ":")
          {String.to_atom(String.trim(prop)), String.to_atom(String.trim(type))}
        end)

      {func_atom, props}
    end)
  end
end
