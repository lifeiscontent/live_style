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

  alias LiveStyle.Property.Validation.{Deprecated, Known, Suggest, VendorPrefix}

  @doc """
  Returns the set of known CSS properties.
  """
  @spec known_properties() :: MapSet.t(String.t())
  defdelegate known_properties(), to: Known

  @doc """
  Checks if a property is a known CSS property.

  Custom properties (starting with `--`) are always considered valid.
  """
  @spec known?(String.t()) :: boolean()
  defdelegate known?(property), to: Known

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
  defdelegate validate(property), to: Suggest

  @doc """
  Validates a property and raises or warns based on configuration.

  Called during compilation to catch typos early. Also checks for
  vendor-prefixed properties that have standard equivalents, and
  warns about deprecated properties.
  """
  @spec validate!(String.t(), keyword()) :: :ok
  def validate!(property, opts \\ []) do
    # First check for vendor prefixes that could be handled by prefix_css
    VendorPrefix.check(property, opts)
    Deprecated.check(property, opts)

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

    message = Suggest.build_unknown_message(property, suggestions)

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

  @doc """
  Finds similar property names for a given unknown property.

  Uses Jaro-Winkler distance for fuzzy matching.
  Returns up to 3 suggestions with similarity > 0.8.
  """
  @spec find_suggestions(String.t()) :: [String.t()]
  defdelegate find_suggestions(property), to: Suggest

  # Configuration helpers
  defp unknown_property_level do
    LiveStyle.Config.unknown_property_level()
  end
end
