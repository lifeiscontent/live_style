defmodule LiveStyle.Property.Validation do
  @moduledoc """
  CSS property validation with "did you mean?" suggestions.

  Validates property names at compile time and provides helpful suggestions
  for typos using string similarity matching. Also warns when vendor-prefixed
  properties are used that could be handled automatically by the prefixer.

  ## Configuration

  Property validation can be configured in your `config.exs`:

      # Enable validation (default: true in dev/test, false in prod)
      config :live_style, validate_properties: true

      # Treat unknown properties as errors (default: :warn)
      config :live_style, unknown_property_level: :error  # :error | :warn | :ignore

      # Treat unnecessary vendor prefixes as warnings (default: :warn)
      config :live_style, vendor_prefix_level: :warn  # :warn | :ignore

  ## Examples

      # This will warn with a suggestion:
      css_class :button,
        opactiy: 0.5  # Warning: Unknown CSS property 'opactiy'. Did you mean 'opacity'?

      # This will warn about vendor prefix:
      css_class :button,
        "-webkit-mask-image": "url(...)"  # Warning: Use 'mask-image' instead...

      # Custom properties are always allowed:
      css_class :button,
        "--my-custom-prop": "value"  # OK
  """

  alias LiveStyle.Data.Parser

  # Load known CSS properties at compile time
  # Source: W3C standard properties + vendor-prefixed properties
  @data_dir Parser.data_dir()
  @known_properties_path Path.join(@data_dir, "css_properties.txt")
  @external_resource @known_properties_path

  @known_properties @known_properties_path
                    |> File.read!()
                    |> String.split("\n", trim: true)
                    |> Enum.reject(&String.starts_with?(&1, "#"))
                    |> MapSet.new()

  # Vendor prefix patterns
  @vendor_prefixes ["-webkit-", "-moz-", "-ms-", "-o-"]

  @doc """
  Returns the set of known CSS properties.
  """
  @spec known_properties() :: MapSet.t(String.t())
  def known_properties, do: @known_properties

  @doc """
  Checks if a property is a known CSS property.

  Custom properties (starting with `--`) are always considered valid.
  """
  @spec known?(String.t()) :: boolean()
  def known?(<<"--", _rest::binary>>), do: true
  def known?(property), do: MapSet.member?(@known_properties, property)

  @doc """
  Validates a property name and returns suggestions if unknown.

  Returns:
  - `:ok` if the property is known
  - `{:unknown, suggestions}` if unknown, with up to 3 similar property names

  ## Examples

      iex> LiveStyle.Property.Validation.validate("opacity")
      :ok

      iex> LiveStyle.Property.Validation.validate("opactiy")
      {:unknown, ["opacity"]}

      iex> LiveStyle.Property.Validation.validate("--custom")
      :ok
  """
  @spec validate(String.t()) :: :ok | {:unknown, [String.t()]}
  def validate(property) do
    if known?(property) do
      :ok
    else
      suggestions = find_suggestions(property)
      {:unknown, suggestions}
    end
  end

  @doc """
  Validates a property and raises or warns based on configuration.

  Called during compilation to catch typos early. Also checks for
  vendor-prefixed properties that have standard equivalents.
  """
  @spec validate!(String.t(), keyword()) :: :ok
  def validate!(property, opts \\ []) do
    # First check for vendor prefixes that could be handled by the prefixer
    check_vendor_prefix(property, opts)

    # Then validate the property is known
    case validate(property) do
      :ok ->
        :ok

      {:unknown, suggestions} ->
        handle_unknown_property(property, suggestions, opts)
    end
  end

  defp handle_unknown_property(property, suggestions, opts) do
    level = Keyword.get(opts, :level, unknown_property_level())
    file = Keyword.get(opts, :file, "unknown")
    line = Keyword.get(opts, :line, 0)

    message = build_message(property, suggestions)
    location = if line > 0, do: "#{file}:#{line}: ", else: ""

    case level do
      :error ->
        raise CompileError, description: message, file: file, line: line

      :warn ->
        IO.warn("#{location}#{message}", [])
        :ok

      :ignore ->
        :ok
    end
  end

  defp build_message(property, []) do
    "Unknown CSS property '#{property}'"
  end

  defp build_message(property, suggestions) do
    suggestion_text = Enum.join(suggestions, ", ")
    "Unknown CSS property '#{property}'. Did you mean: #{suggestion_text}?"
  end

  @doc """
  Finds similar property names for a given unknown property.

  Uses Jaro-Winkler distance for fuzzy matching.
  Returns up to 3 suggestions with similarity > 0.8.
  """
  @spec find_suggestions(String.t()) :: [String.t()]
  def find_suggestions(property) do
    property_downcase = String.downcase(property)

    @known_properties
    |> Enum.map(fn known ->
      {known, String.jaro_distance(property_downcase, String.downcase(known))}
    end)
    |> Enum.filter(fn {_prop, score} -> score > 0.8 end)
    |> Enum.sort_by(fn {_prop, score} -> -score end)
    |> Enum.take(3)
    |> Enum.map(fn {prop, _score} -> prop end)
  end

  # Vendor prefix checking
  defp check_vendor_prefix(property, opts) do
    case extract_standard_property(property) do
      nil ->
        :ok

      standard_property ->
        if prefixer_handles_property?(standard_property) do
          handle_vendor_prefix(property, standard_property, opts)
        else
          :ok
        end
    end
  end

  # Extract the standard property name from a vendor-prefixed property
  # Returns nil if not a vendor-prefixed property
  defp extract_standard_property(property) do
    Enum.find_value(@vendor_prefixes, fn prefix ->
      if String.starts_with?(property, prefix) do
        String.replace_prefix(property, prefix, "")
      end
    end)
  end

  # Check if the configured prefixer handles this property
  defp prefixer_handles_property?(property) do
    case LiveStyle.Config.prefixer() do
      nil ->
        false

      module when is_atom(module) ->
        # Check if module has needs_prefix?/1 function
        if function_exported?(module, :needs_prefix?, 1) do
          module.needs_prefix?(property)
        else
          false
        end

      fun when is_function(fun, 2) ->
        # For function prefixers, check if the output differs from input
        result = fun.(property, "test")
        result != "#{property}:test"
    end
  end

  defp handle_vendor_prefix(prefixed_property, standard_property, opts) do
    level = Keyword.get(opts, :vendor_prefix_level, vendor_prefix_level())
    file = Keyword.get(opts, :file, "unknown")
    line = Keyword.get(opts, :line, 0)

    message = build_vendor_prefix_message(prefixed_property, standard_property)
    location = if line > 0, do: "#{file}:#{line}: ", else: ""

    case level do
      :warn ->
        IO.warn("#{location}#{message}", [])
        :ok

      :ignore ->
        :ok
    end
  end

  defp build_vendor_prefix_message(prefixed_property, standard_property) do
    "Unnecessary vendor prefix '#{prefixed_property}'. " <>
      "Use '#{standard_property}' instead - the prefixer will add vendor prefixes automatically."
  end

  # Configuration helpers
  defp unknown_property_level do
    LiveStyle.Config.unknown_property_level()
  end

  defp vendor_prefix_level do
    LiveStyle.Config.vendor_prefix_level()
  end
end
