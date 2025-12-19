defmodule LiveStyle.Autoprefixer do
  @moduledoc """
  Automatic vendor prefix generation for CSS properties.

  Adds vendor prefixes based on browser support data. Uses a curated list of
  properties that need prefixes for modern browsers (based on browserslist "defaults").

  ## Configuration

      # config/config.exs
      config :live_style,
        # Enable/disable autoprefixing (default: true)
        autoprefixer: true

  ## How It Works

  When autoprefixing is enabled, LiveStyle generates both the prefixed and
  unprefixed versions of properties that need vendor prefixes. For example:

      css_class :button,
        user_select: "none"

  Generates:

      .x123 { -webkit-user-select: none; -moz-user-select: none; user-select: none; }

  ## Supported Prefixes

  Based on browserslist "defaults" (covers ~86% of global users), the following
  properties receive vendor prefixes:

  - `-webkit-` prefixes for Safari/Chrome/iOS
  - `-moz-` prefixes for Firefox

  Properties like `transform`, `transition`, `flexbox`, etc. no longer need
  prefixes for modern browsers.
  """

  alias LiveStyle.Config

  # Property -> list of prefixes needed for modern browsers
  # Based on autoprefixer with browserslist "defaults"
  # Last updated: 2024
  @prefix_data %{
    # Appearance
    "appearance" => ["-webkit-", "-moz-"],

    # Background
    "background-clip" => ["-webkit-"],

    # Box decoration
    "box-decoration-break" => ["-webkit-"],

    # Break properties (for Firefox)
    "break-after" => ["-moz-"],
    "break-before" => ["-moz-"],
    "break-inside" => ["-moz-"],

    # Color adjust / print
    "color-adjust" => ["-webkit-"],
    "print-color-adjust" => ["-webkit-"],

    # Multi-column (Firefox still needs prefix)
    "column-count" => ["-moz-"],
    "column-fill" => ["-moz-"],
    "column-gap" => ["-moz-"],
    "column-rule" => ["-moz-"],
    "column-rule-color" => ["-moz-"],
    "column-rule-style" => ["-moz-"],
    "column-rule-width" => ["-moz-"],
    "column-span" => ["-moz-"],
    "column-width" => ["-moz-"],
    "columns" => ["-moz-"],

    # Mask properties (Safari needs prefix)
    "mask" => ["-webkit-"],
    "mask-border" => ["-webkit-"],
    "mask-border-outset" => ["-webkit-"],
    "mask-border-repeat" => ["-webkit-"],
    "mask-border-slice" => ["-webkit-"],
    "mask-border-source" => ["-webkit-"],
    "mask-border-width" => ["-webkit-"],
    "mask-clip" => ["-webkit-"],
    "mask-composite" => ["-webkit-"],
    "mask-image" => ["-webkit-"],
    "mask-origin" => ["-webkit-"],
    "mask-position" => ["-webkit-"],
    "mask-repeat" => ["-webkit-"],
    "mask-size" => ["-webkit-"],

    # Tab size
    "tab-size" => ["-moz-"],

    # Text alignment
    "text-align-last" => ["-moz-"],

    # Text decoration (Safari needs prefix for some)
    "text-decoration" => ["-webkit-"],
    "text-decoration-skip" => ["-webkit-"],
    "text-decoration-skip-ink" => ["-webkit-"],

    # Text emphasis
    "text-emphasis" => ["-webkit-"],
    "text-emphasis-color" => ["-webkit-"],
    "text-emphasis-position" => ["-webkit-"],
    "text-emphasis-style" => ["-webkit-"],

    # Text size adjust
    "text-size-adjust" => ["-webkit-", "-moz-"],

    # User select
    "user-select" => ["-webkit-", "-moz-"]
  }

  @doc """
  Returns the prefix data map.
  """
  @spec prefix_data() :: map()
  def prefix_data, do: @prefix_data

  @doc """
  Checks if a property needs vendor prefixes.
  """
  @spec needs_prefix?(String.t()) :: boolean()
  def needs_prefix?(property) do
    Map.has_key?(@prefix_data, property)
  end

  @doc """
  Returns the list of prefixes needed for a property.

  Returns an empty list if no prefixes are needed.
  """
  @spec prefixes_for(String.t()) :: [String.t()]
  def prefixes_for(property) do
    Map.get(@prefix_data, property, [])
  end

  @doc """
  Generates prefixed CSS declarations for a property-value pair.

  Returns a list of `{property, value}` tuples including both prefixed
  and unprefixed versions.

  ## Examples

      iex> LiveStyle.Autoprefixer.prefix("user-select", "none")
      [{"-webkit-user-select", "none"}, {"-moz-user-select", "none"}, {"user-select", "none"}]

      iex> LiveStyle.Autoprefixer.prefix("display", "flex")
      [{"display", "flex"}]
  """
  @spec prefix(String.t(), String.t()) :: [{String.t(), String.t()}]
  def prefix(property, value) do
    if Config.autoprefixer?() and needs_prefix?(property) do
      prefixes = prefixes_for(property)

      prefixed =
        Enum.map(prefixes, fn prefix ->
          {prefix <> property, value}
        end)

      prefixed ++ [{property, value}]
    else
      [{property, value}]
    end
  end

  @doc """
  Generates prefixed CSS rule string for a property-value pair.

  ## Examples

      iex> LiveStyle.Autoprefixer.prefix_css("user-select", "none")
      "-webkit-user-select:none;-moz-user-select:none;user-select:none"

      iex> LiveStyle.Autoprefixer.prefix_css("display", "flex")
      "display:flex"
  """
  @spec prefix_css(String.t(), String.t()) :: String.t()
  def prefix_css(property, value) do
    property
    |> prefix(value)
    |> Enum.map(fn {prop, val} -> "#{prop}:#{val}" end)
    |> Enum.join(";")
  end
end
