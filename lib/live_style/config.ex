defmodule LiveStyle.Config do
  @moduledoc """
  Configuration management for LiveStyle.

  ## Profiles

  You can define multiple LiveStyle profiles. By default, there is a
  profile called `:default` which you can configure:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
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

    * `:use_css_layers` - wrap CSS output in `@layer` blocks for specificity
      (default: true). When false, uses `:not(#\\#)` selector hack instead
      (matching StyleX's default behavior)

    * `:use_priority_layers` - when `use_css_layers` is true, groups CSS rules
      by priority level into separate `@layer priorityN` blocks (default: false).
      This matches StyleX's `useLayers: true` behavior where rules are grouped
      as: `@layer priority1, priority2, ...; @layer priority2 { rules... }`

  ## Example Configuration

      # config/config.exs
      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

      # Custom manifest path
      config :live_style,
        manifest_path: "custom/manifest.etf"

      # config/dev.exs
      config :live_style,
        debug_class_names: true

  ## Per-Process Overrides

      LiveStyle.Config.put(:shorthand_behavior, :forbid_shorthands)
      # ... run code with :forbid_shorthands mode ...
      LiveStyle.Config.reset_all()
  """

  @default_shorthand_behavior LiveStyle.ShorthandBehavior.AcceptShorthands
  @default_class_name_prefix "x"
  @default_debug_class_names false
  @default_font_size_px_to_rem false
  @default_font_size_root_px 16
  @default_use_css_layers true
  @default_use_priority_layers false

  @config_key :live_style_config_overrides

  @doc """
  Returns the configuration for the given profile.

  Raises if the profile does not exist.

  ## Example

      LiveStyle.Config.config_for!(:default)
      #=> [output: "priv/static/assets/live.css", cd: "/path/to/project"]
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:live_style, profile) ||
      raise ArgumentError, """
      unknown LiveStyle profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :live_style,
            #{profile}: [
              output: "priv/static/assets/live.css",
              cd: Path.expand("..", __DIR__)
            ]
      """
  end

  @doc """
  Sets a per-process configuration override.

  This is primarily used for test isolation, allowing each test to use
  different configuration without affecting other tests.
  """
  def put(key, value) do
    overrides = Process.get(@config_key, %{})
    Process.put(@config_key, Map.put(overrides, key, value))
    :ok
  end

  # Gets a per-process configuration override.
  # Returns `nil` if no override is set.
  defp get_override(key) do
    overrides = Process.get(@config_key, %{})
    Map.get(overrides, key)
  end

  @doc """
  Resets all per-process configuration overrides.
  """
  def reset_all do
    Process.delete(@config_key)
    :ok
  end

  @doc """
  Resets a specific per-process configuration override.
  """
  def reset(key) do
    overrides = Process.get(@config_key, %{})
    Process.put(@config_key, Map.delete(overrides, key))
    :ok
  end

  @doc """
  Returns the configured output path for CSS.

  This is a convenience function that returns the default profile's output path.
  For profile-specific paths, use `config_for!/1`.
  """
  def output_path do
    get_override(:output_path) ||
      case Application.get_env(:live_style, :default) do
        nil -> "priv/static/assets/live.css"
        config -> Keyword.get(config, :output, "priv/static/assets/live.css")
      end
  end

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
  @atom_to_behavior_module %{
    accept_shorthands: LiveStyle.ShorthandBehavior.AcceptShorthands,
    flatten_shorthands: LiveStyle.ShorthandBehavior.FlattenShorthands,
    forbid_shorthands: LiveStyle.ShorthandBehavior.ForbidShorthands
  }

  def shorthand_behavior do
    value =
      get_override(:shorthand_behavior) ||
        Application.get_env(:live_style, :shorthand_behavior, @default_shorthand_behavior)

    case normalize_shorthand_behavior(value) do
      {:ok, result} ->
        result

      :error ->
        raise ArgumentError, """
        Invalid shorthand_behavior: #{inspect(value)}

        Valid formats are:
        - An atom: :accept_shorthands, :flatten_shorthands, :forbid_shorthands
        - A module: LiveStyle.ShorthandBehavior.AcceptShorthands
        - A tuple: {MyCustomBehavior, some_option: true}
        """
    end
  end

  defp normalize_shorthand_behavior(atom) when is_map_key(@atom_to_behavior_module, atom) do
    {:ok, {Map.fetch!(@atom_to_behavior_module, atom), []}}
  end

  defp normalize_shorthand_behavior({module, opts}) when is_atom(module) and is_list(opts) do
    if valid_behavior_module?(module) do
      {:ok, {module, opts}}
    else
      :error
    end
  end

  defp normalize_shorthand_behavior(module) when is_atom(module) do
    if valid_behavior_module?(module) do
      {:ok, {module, []}}
    else
      :error
    end
  end

  defp normalize_shorthand_behavior(_), do: :error

  defp valid_behavior_module?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :expand_declaration, 3) and
      function_exported?(module, :expand_shorthand_conditions, 3)
  end

  @doc """
  Returns the configured class name prefix.

  Default is "x" (matching StyleX). This prefix is used for all generated
  class names, variable names, keyframe names, etc.
  """
  def class_name_prefix do
    value =
      get_override(:class_name_prefix) ||
        Application.get_env(:live_style, :class_name_prefix, @default_class_name_prefix)

    unless is_binary(value) and String.length(value) > 0 do
      raise ArgumentError, """
      Invalid class_name_prefix: #{inspect(value)}

      class_name_prefix must be a non-empty string.
      """
    end

    value
  end

  @doc """
  Returns whether debug class names are enabled.

  When enabled, class names include the property name for easier debugging:
  - Disabled: `x1a2b3c4`
  - Enabled: `backgroundColor-x1a2b3c4`

  Default is `false`. Enable in development for easier debugging:

      config :live_style, debug_class_names: true
  """
  def debug_class_names? do
    get_override(:debug_class_names) ||
      Application.get_env(:live_style, :debug_class_names, @default_debug_class_names)
  end

  @doc """
  Returns whether font-size px to rem conversion is enabled.

  When enabled, numeric font-size values in px are converted to rem for
  better accessibility (respects user's browser font size settings).

  Default is `false`. Enable for accessibility:

      config :live_style,
        font_size_px_to_rem: true,
        font_size_root_px: 16  # optional, default is 16
  """
  def font_size_px_to_rem? do
    get_override(:font_size_px_to_rem) ||
      Application.get_env(:live_style, :font_size_px_to_rem, @default_font_size_px_to_rem)
  end

  @doc """
  Returns the root font size in pixels for px to rem conversion.

  Default is 16 (browser default). Used when `font_size_px_to_rem` is enabled.
  """
  def font_size_root_px do
    get_override(:font_size_root_px) ||
      Application.get_env(:live_style, :font_size_root_px, @default_font_size_root_px)
  end

  @doc """
  Returns whether CSS layers should be used for specificity control.

  When enabled (default), output is wrapped in `@layer live_style { ... }`.
  When disabled, uses the `:not(#\\#)` selector hack instead, matching
  StyleX's default behavior.

  CSS layers are the modern approach but may conflict with user's own
  `@layer` declarations. The `:not(#\\#)` hack works in all browsers but
  is less elegant.

  Default is `true`. Disable for StyleX compatibility:

      config :live_style, use_css_layers: false
  """
  def use_css_layers? do
    case get_override(:use_css_layers) do
      nil -> Application.get_env(:live_style, :use_css_layers, @default_use_css_layers)
      value -> value
    end
  end

  @doc """
  Returns whether priority layers should be used for CSS rule grouping.

  When enabled (and `use_css_layers?` is true), CSS rules are grouped by
  priority level into separate `@layer priorityN` blocks. This matches
  StyleX's `useLayers: true` behavior.

  Priority levels are calculated as `div(priority, 1000)`:
  - Priority 0-999 → @layer priority1 (non-style rules like @property, @keyframes)
  - Priority 1000-1999 → @layer priority2 (shorthand of shorthands)
  - Priority 2000-2999 → @layer priority3 (shorthand of longhands)
  - Priority 3000-3999 → @layer priority4 (regular properties)
  - Priority 4000-4999 → @layer priority5 (physical longhands)
  - Priority 5000+ → @layer priority6+ (pseudo-elements)

  Default is `false` (matching StyleX's default). Enable for StyleX `useLayers: true` compatibility:

      config :live_style,
        use_css_layers: true,
        use_priority_layers: true
  """
  def use_priority_layers? do
    case get_override(:use_priority_layers) do
      nil -> Application.get_env(:live_style, :use_priority_layers, @default_use_priority_layers)
      value -> value
    end
  end
end
