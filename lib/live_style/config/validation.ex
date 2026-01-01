defmodule LiveStyle.Config.Validation do
  @moduledoc """
  Configuration for CSS property validation.

  Controls how LiveStyle validates property names and handles
  unknown, vendor-prefixed, and deprecated properties.
  """

  alias LiveStyle.Config.Overrides

  @default_validate_properties true
  @default_unknown_property_level :warn
  @default_vendor_prefix_level :warn
  @default_deprecated_property_level :warn
  @default_deprecated? nil

  @doc """
  Returns whether property validation is enabled.

  When enabled, LiveStyle validates CSS property names at compile time and
  warns or errors on unknown properties with "did you mean?" suggestions.

  Custom properties (starting with `--`) are always allowed.

  Default is `true`. Disable if you need to use non-standard properties:

      config :live_style, validate_properties: false
  """
  @spec validate_properties?() :: boolean()
  def validate_properties? do
    Overrides.get_config(:validate_properties, @default_validate_properties)
  end

  @doc """
  Returns the level of unknown property handling.

  - `:warn` (default) - Log a warning with suggestions
  - `:error` - Raise a CompileError
  - `:ignore` - Silently allow unknown properties

  Example:

      config :live_style, unknown_property_level: :error
  """
  @spec unknown_property_level() :: :warn | :error | :ignore
  def unknown_property_level do
    Overrides.get_config(:unknown_property_level, @default_unknown_property_level)
  end

  @doc """
  Returns the level of vendor prefix property handling.

  When a vendor-prefixed property is used (e.g., `-webkit-mask-image`) and
  the configured `prefix_css` would add that prefix automatically for the
  standard property (e.g., `mask-image`), this setting controls the behavior.

  - `:warn` (default) - Log a warning suggesting to use the standard property
  - `:ignore` - Silently allow vendor-prefixed properties

  Example:

      config :live_style, vendor_prefix_level: :ignore
  """
  @spec vendor_prefix_level() :: :warn | :ignore
  def vendor_prefix_level do
    Overrides.get_config(:vendor_prefix_level, @default_vendor_prefix_level)
  end

  @doc """
  Returns the level of deprecated property handling.

  When a deprecated CSS property is used (e.g., `clip`), this setting
  controls the behavior. Requires the `deprecated?` config to be set.

  - `:warn` (default) - Log a warning about the deprecated property
  - `:ignore` - Silently allow deprecated properties

  Example:

      config :live_style, deprecated_property_level: :ignore
  """
  @spec deprecated_property_level() :: :warn | :ignore
  def deprecated_property_level do
    Overrides.get_config(:deprecated_property_level, @default_deprecated_property_level)
  end

  @doc """
  Returns the `deprecated?` function for checking deprecated CSS properties.

  Used during validation to check if properties are deprecated. Should be a
  function that takes a property name and returns a boolean (or nil if unknown).

  Default is `nil` (no deprecation checking).

  ## Configuration

      config :live_style, deprecated?: &MyApp.CSS.deprecated?/1

  ## Function Signature

      @spec deprecated?(String.t()) :: boolean() | nil
  """
  @spec deprecated?() :: (String.t() -> boolean() | nil) | nil
  def deprecated? do
    Overrides.get_config(:deprecated?, @default_deprecated?)
  end
end
