defmodule LiveStyle.Config do
  @moduledoc """
  Configuration management for LiveStyle.

  This module provides access to all LiveStyle configuration options.
  Complex configuration logic is split into focused submodules:

  - `LiveStyle.Config.Validation` - property validation settings
  - `LiveStyle.Config.Shorthand` - shorthand expansion behavior

  ## Profiles

  You can define multiple LiveStyle profiles. By default, there is a
  profile called `:default` which you can configure:

      config :live_style,
        default: [
          output: "priv/static/assets/css/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Global Configuration

  There are several global configurations for the LiveStyle application:

    * `:manifest_path` - path where the manifest file is stored
      (default: `"_build/live_style_manifest.etf"`)

    * `:shorthand_behavior` - the shorthand expansion behavior
      (default: `LiveStyle.ShorthandBehavior.AcceptShorthands`)

      Can be specified as:
      - An atom: `:accept_shorthands`, `:flatten_shorthands`, `:forbid_shorthands`
      - A module: `LiveStyle.ShorthandBehavior.AcceptShorthands`
      - A tuple with options: `{MyCustomBehavior, some_option: true}`

    * `:class_name_prefix` - prefix for generated class names
      (default: "x")

    * `:debug_class_names` - include property names in class names
      (default: false)

    * `:font_size_px_to_rem` - convert font-size px values to rem
      (default: false)

    * `:font_size_root_px` - root font size for px to rem conversion
      (default: 16)

    * `:use_css_layers` - use CSS `@layer` for specificity control (default: false).
      When true, groups rules by priority into `@layer priorityN` blocks
      (matching StyleX's `useLayers: true`).
      When false, uses `:not(#\\#)` selector hack instead (matching StyleX's default)

    * `:validate_properties` - validate CSS property names at compile time (default: true)

    * `:unknown_property_level` - how to handle unknown CSS properties (default: `:warn`)
      - `:error` - raise compile-time error
      - `:warn` - emit warning with "did you mean?" suggestions
      - `:ignore` - silently ignore

    * `:vendor_prefix_level` - how to handle unnecessary vendor prefixes (default: `:warn`)
      - `:warn` - emit warning suggesting to use the unprefixed property
      - `:ignore` - silently allow

    * `:deprecated_property_level` - how to handle deprecated CSS properties (default: `:warn`)
      - `:warn` - emit warning about deprecated property
      - `:ignore` - silently allow

    * `:prefix_css` - function to add vendor prefixes to CSS (default: nil)
      - Example: `&MyAppWeb.CSS.prefix/2` - should take `(property, value)` and return CSS string

    * `:deprecated?` - function to check if a property is deprecated (default: nil)
      - Example: `&MyAppWeb.CSS.deprecated?/1` - should take property name and return boolean

  ## Example Configuration

      # config/config.exs
      config :live_style,
        default: [
          output: "priv/static/assets/css/live.css",
          cd: Path.expand("..", __DIR__)
        ]

      # Custom manifest path
      config :live_style,
        manifest_path: "custom/manifest.etf"

      # config/dev.exs
      config :live_style,
        debug_class_names: true

  ## Compile-Time Only

  All style-affecting configuration is compile-time only (like StyleX's Babel plugin config).
  Changing these settings requires recompiling your LiveStyle modules.
  """

  alias LiveStyle.Config.Overrides
  alias LiveStyle.Config.Shorthand
  alias LiveStyle.Config.Validation

  # ===========================================================================
  # Compile-Time Configuration (like StyleX Babel plugin config)
  # These are read at compile time and baked into the generated code.
  # Changing these requires recompilation.
  # ===========================================================================

  @class_name_prefix Application.compile_env(:live_style, :class_name_prefix, "x")
  @debug_class_names Application.compile_env(:live_style, :debug_class_names, false)
  @font_size_px_to_rem Application.compile_env(:live_style, :font_size_px_to_rem, false)
  @font_size_root_px Application.compile_env(:live_style, :font_size_root_px, 16)

  # ===========================================================================
  # Profile Configuration
  # ===========================================================================

  @doc """
  Returns the configuration for the given profile.

  Raises if the profile does not exist.

  ## Example

      LiveStyle.Config.config_for!(:default)
      #=> [output: "priv/static/assets/css/live.css", cd: "/path/to/project"]
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:live_style, profile) ||
      raise ArgumentError, """
      unknown LiveStyle profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :live_style,
            #{profile}: [
              output: "priv/static/assets/css/live.css",
              cd: Path.expand("..", __DIR__)
            ]
      """
  end

  @doc """
  Returns the configured output path for CSS.

  This is a convenience function that returns the default profile's output path.
  For profile-specific paths, use `config_for!/1`.
  """
  def output_path do
    Overrides.get(:output_path) ||
      case Application.get_env(:live_style, :default) do
        nil -> "priv/static/assets/css/live.css"
        config -> Keyword.get(config, :output, "priv/static/assets/css/live.css")
      end
  end

  # ===========================================================================
  # Naming Configuration
  # ===========================================================================

  @doc """
  Returns the configured class name prefix.

  Default is "x" (matching StyleX). This prefix is used for all generated
  class names, variable names, keyframe names, etc.
  """
  @spec class_name_prefix() :: String.t()
  def class_name_prefix do
    @class_name_prefix
  end

  @doc """
  Returns whether debug class names are enabled.

  When enabled, class names include the property name for easier debugging:
  - Disabled: `x1a2b3c4`
  - Enabled: `backgroundColor-x1a2b3c4`

  Default is `false`. Enable in development for easier debugging:

      config :live_style, debug_class_names: true
  """
  @spec debug_class_names?() :: boolean()
  def debug_class_names? do
    @debug_class_names
  end

  # ===========================================================================
  # Shorthand Configuration
  # ===========================================================================

  @doc """
  Returns the configured shorthand expansion behavior and options.

  Returns a tuple of `{module, opts}` where opts is a keyword list.

  ## Examples

      # Default
      shorthand_behavior() #=> {LiveStyle.ShorthandBehavior.AcceptShorthands, []}

      # Using atom shortcut
      shorthand_behavior() #=> {LiveStyle.ShorthandBehavior.FlattenShorthands, []}

      # Custom behavior with options
      shorthand_behavior() #=> {MyCustomBehavior, [strict: true]}
  """
  defdelegate shorthand_behavior(), to: Shorthand

  # ===========================================================================
  # Font Size Configuration
  # ===========================================================================

  @doc """
  Returns whether font-size px to rem conversion is enabled.

  When enabled, numeric font-size values in px are converted to rem for
  better accessibility (respects user's browser font size settings).

  Default is `false`. Enable for accessibility:

      config :live_style,
        font_size_px_to_rem: true,
        font_size_root_px: 16  # optional, default is 16
  """
  @spec font_size_px_to_rem?() :: boolean()
  def font_size_px_to_rem? do
    @font_size_px_to_rem
  end

  @doc """
  Returns the root font size in pixels for px to rem conversion.

  Default is 16 (browser default). Used when `font_size_px_to_rem` is enabled.
  """
  @spec font_size_root_px() :: number()
  def font_size_root_px do
    @font_size_root_px
  end

  # ===========================================================================
  # Validation Configuration
  # ===========================================================================

  @doc """
  Returns whether property validation is enabled.

  When enabled, LiveStyle validates CSS property names at compile time and
  warns or errors on unknown properties with "did you mean?" suggestions.

  Custom properties (starting with `--`) are always allowed.

  Default is `true`. Disable if you need to use non-standard properties:

      config :live_style, validate_properties: false
  """
  defdelegate validate_properties?(), to: Validation

  @doc """
  Returns the level of unknown property handling.

  - `:warn` (default) - Log a warning with suggestions
  - `:error` - Raise a CompileError
  - `:ignore` - Silently allow unknown properties

  Example:

      config :live_style, unknown_property_level: :error
  """
  defdelegate unknown_property_level(), to: Validation

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
  defdelegate vendor_prefix_level(), to: Validation

  @doc """
  Returns the level of deprecated property handling.

  When a deprecated CSS property is used (e.g., `clip`), this setting
  controls the behavior. Requires the `deprecated?` config to be set.

  - `:warn` (default) - Log a warning about the deprecated property
  - `:ignore` - Silently allow deprecated properties

  Example:

      config :live_style, deprecated_property_level: :ignore
  """
  defdelegate deprecated_property_level(), to: Validation

  @doc """
  Returns the `deprecated?` function for checking deprecated CSS properties.

  Used during validation to check if properties are deprecated. Should be a
  function that takes a property name and returns a boolean (or nil if unknown).

  Default is `nil` (no deprecation checking).

  ## Configuration

      config :live_style, deprecated?: &MyAppWeb.CSS.deprecated?/1

  ## Function Signature

      @spec deprecated?(String.t()) :: boolean() | nil
  """
  defdelegate deprecated?(), to: Validation

  # ===========================================================================
  # CSS Output Configuration
  # ===========================================================================

  @doc """
  Returns whether CSS layers should be used for specificity control.

  When enabled, CSS rules are grouped by priority level into separate
  `@layer priorityN` blocks. This matches StyleX's `useLayers: true` behavior.

  Priority levels are calculated as `div(priority, 1000)`:
  - Priority 0-999 → @layer priority1 (non-style rules like @property, @keyframes)
  - Priority 1000-1999 → @layer priority2 (shorthand of shorthands)
  - Priority 2000-2999 → @layer priority3 (shorthand of longhands)
  - Priority 3000-3999 → @layer priority4 (regular properties)
  - Priority 4000-4999 → @layer priority5 (physical longhands)
  - Priority 5000+ → @layer priority6+ (pseudo-elements)

  When disabled (default), uses the `:not(#\\#)` selector hack instead,
  matching StyleX's default behavior.

  Enable for StyleX `useLayers: true` compatibility:

      config :live_style, use_css_layers: true
  """
  def use_css_layers? do
    Application.get_env(:live_style, :use_css_layers, false)
  end

  @doc """
  Returns the `prefix_css` function for adding vendor prefixes.

  Called during CSS generation to add vendor prefixes. Should be a function
  that takes `(property, value)` and returns a CSS string with any needed prefixes.

  Default is `nil` (no prefixing).

  ## Configuration

      config :live_style, prefix_css: &MyAppWeb.CSS.prefix/2

  ## Function Signature

      @spec prefix_css(String.t(), String.t()) :: String.t()

  ## Example Implementation

      def prefix_css("user-select", value) do
        "-webkit-user-select:\#{value};user-select:\#{value}"
      end
      def prefix_css(property, value), do: "\#{property}:\#{value}"
  """
  def prefix_css do
    Application.get_env(:live_style, :prefix_css)
  end

  @doc """
  Applies the configured `prefix_css` function to a property-value pair.

  Returns the CSS string. If no `prefix_css` is configured, returns
  the standard "property:value" format.
  """
  @spec apply_prefix_css(String.t(), String.t()) :: String.t()
  def apply_prefix_css(property, value) do
    case prefix_css() do
      nil -> "#{property}:#{value}"
      {mod, fun} -> apply(mod, fun, [property, value])
      prefix_fun when is_function(prefix_fun, 2) -> prefix_fun.(property, value)
    end
  end
end
