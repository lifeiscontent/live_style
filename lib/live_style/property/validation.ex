defmodule LiveStyle.Property.Validation do
  @moduledoc """
  CSS property validation with "did you mean?" suggestions.

  Validates property names at compile time and provides helpful suggestions
  for typos using string similarity matching. Also warns when vendor-prefixed
  properties are used that could be handled automatically by `prefix_css`,
  and when deprecated properties are used.

  ## Configuration

  Property validation can be configured in your `config.exs`:

      # Enable validation (default: true in dev/test, false in prod)
      config :live_style, validate_properties: true

      # Treat unknown properties as errors (default: :warn)
      config :live_style, unknown_property_level: :error  # :error | :warn | :ignore

      # Treat unnecessary vendor prefixes as warnings (default: :warn)
      config :live_style, vendor_prefix_level: :warn  # :warn | :ignore

      # Treat deprecated properties as warnings (default: :warn)
      config :live_style, deprecated_property_level: :warn  # :warn | :ignore

      # Configure deprecation checking function (any function that returns boolean)
      config :live_style, deprecated?: &MyApp.CSS.deprecated?/1

  ## Examples

      # This will warn with a suggestion:
      css_class :button,
        opactiy: 0.5  # Warning: Unknown CSS property 'opactiy'. Did you mean 'opacity'?

      # This will warn about vendor prefix:
      css_class :button,
        "-webkit-mask-image": "url(...)"  # Warning: Use 'mask-image' instead...

      # This will warn about deprecated property:
      css_class :button,
        clip: "rect(0,0,0,0)"  # Warning: CSS property 'clip' is deprecated...

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

  @known_properties_list @known_properties_path
                         |> File.read!()
                         |> String.split("\n", trim: true)
                         |> Enum.reject(&String.starts_with?(&1, "#"))

  @known_properties MapSet.new(@known_properties_list)

  @doc """
  Returns the set of known CSS properties.
  """
  @spec known_properties() :: MapSet.t(String.t())
  def known_properties, do: @known_properties

  @doc """
  Checks if a property is a known CSS property.

  Custom properties (starting with `--`) are always considered valid.
  Uses pattern matching for optimal runtime performance.
  """
  @spec known?(String.t()) :: boolean()
  def known?(<<"--", _rest::binary>>), do: true

  # Generate pattern-matched function clauses for all known properties
  for property <- @known_properties_list do
    def known?(unquote(property)), do: true
  end

  def known?(_), do: false

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
  vendor-prefixed properties that have standard equivalents, and
  warns about deprecated properties.
  """
  @spec validate!(String.t(), keyword()) :: :ok
  def validate!(property, opts \\ []) do
    # First check for vendor prefixes that could be handled by prefix_css
    check_vendor_prefix(property, opts)

    # Check for deprecated properties (if deprecated? is configured)
    check_deprecated_property(property, opts)

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
        if prefix_css_handles_property?(standard_property) do
          handle_vendor_prefix(property, standard_property, opts)
        else
          :ok
        end
    end
  end

  # Extract the standard property name from a vendor-prefixed property
  # Returns nil if not a vendor-prefixed property
  # Uses binary pattern matching for performance
  defp extract_standard_property(<<"-webkit-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-moz-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-ms-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-o-", rest::binary>>), do: rest
  defp extract_standard_property(_), do: nil

  # Check if the configured prefix_css handles this property
  defp prefix_css_handles_property?(property) do
    case LiveStyle.Config.prefix_css() do
      nil ->
        false

      fun when is_function(fun, 2) ->
        # Check if the output differs from input (meaning it added prefixes)
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
      "Use '#{standard_property}' instead - prefix_css will add vendor prefixes automatically."
  end

  # Deprecated property checking (requires deprecated? config)
  # Skip custom properties (starting with --)
  defp check_deprecated_property(<<"--", _::binary>>, _opts), do: :ok

  defp check_deprecated_property(property, opts) do
    if property_deprecated?(property) do
      handle_deprecated_property(property, opts)
    else
      :ok
    end
  end

  defp property_deprecated?(property) do
    case LiveStyle.Config.deprecated?() do
      nil ->
        false

      fun when is_function(fun, 1) ->
        fun.(property)
    end
  end

  defp handle_deprecated_property(property, opts) do
    level = Keyword.get(opts, :deprecated_property_level, deprecated_property_level())
    file = Keyword.get(opts, :file, "unknown")
    line = Keyword.get(opts, :line, 0)

    message = build_deprecated_message(property)
    location = if line > 0, do: "#{file}:#{line}: ", else: ""

    case level do
      :warn ->
        IO.warn("#{location}#{message}", [])
        :ok

      :ignore ->
        :ok
    end
  end

  defp build_deprecated_message(property) do
    "CSS property '#{property}' is deprecated. Consider using a modern alternative."
  end

  # Configuration helpers
  defp unknown_property_level do
    LiveStyle.Config.unknown_property_level()
  end

  defp vendor_prefix_level do
    LiveStyle.Config.vendor_prefix_level()
  end

  defp deprecated_property_level do
    LiveStyle.Config.deprecated_property_level()
  end
end
