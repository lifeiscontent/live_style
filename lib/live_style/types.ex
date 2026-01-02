defmodule LiveStyle.Types do
  @moduledoc """
  Typed CSS custom property helpers for `@property` rule generation.

  These functions create type specifications for CSS custom properties,
  enabling smooth transitions and animations on custom properties.

  This module aligns with StyleX's `stylex.types` API.

  ## Examples

      import LiveStyle.Types

      vars [
        rotation: angle("0deg"),
        progress: percentage("0%"),
        scale: number(1)
      ]

  ## Generated CSS

      @property --rotation {
        syntax: "<angle>";
        inherits: true;
        initial-value: 0deg;
      }
  """

  @type property_type :: [
          {:syntax, String.t()}
          | {:initial, String.t() | number()}
          | {:inherits, boolean()}
        ]

  @doc """
  Angle type (`<angle>`).

  Accepts values like `0deg`, `90deg`, `0.5turn`.
  """
  @spec angle(String.t()) :: property_type()
  def angle(initial) do
    [syntax: "<angle>", initial: initial, inherits: true]
  end

  @doc """
  Color type (`<color>`).

  Accepts any valid CSS color value.
  """
  @spec color(String.t()) :: property_type()
  def color(initial) do
    [syntax: "<color>", initial: initial, inherits: true]
  end

  @doc """
  Image type (`<image>`).

  Accepts url(), gradient functions, etc.
  """
  @spec image(String.t()) :: property_type()
  def image(initial) do
    [syntax: "<image>", initial: initial, inherits: true]
  end

  @doc """
  Integer type (`<integer>`).

  Accepts whole numbers only.
  """
  @spec integer(integer()) :: property_type()
  def integer(initial) do
    [syntax: "<integer>", initial: initial, inherits: true]
  end

  @doc """
  Length type (`<length>`).

  Accepts values like `0px`, `1rem`, `10vh`.
  """
  @spec length(String.t()) :: property_type()
  def length(initial) do
    [syntax: "<length>", initial: initial, inherits: true]
  end

  @doc """
  Length or percentage type (`<length-percentage>`).

  Accepts lengths or percentages.
  """
  @spec length_percentage(String.t()) :: property_type()
  def length_percentage(initial) do
    [syntax: "<length-percentage>", initial: initial, inherits: true]
  end

  @doc """
  Number type (`<number>`).

  Accepts any numeric value (integers or decimals).
  """
  @spec number(number()) :: property_type()
  def number(initial) do
    [syntax: "<number>", initial: initial, inherits: true]
  end

  @doc """
  Percentage type (`<percentage>`).

  Accepts percentage values like `50%`, `100%`.
  """
  @spec percentage(String.t()) :: property_type()
  def percentage(initial) do
    [syntax: "<percentage>", initial: initial, inherits: true]
  end

  @doc """
  Resolution type (`<resolution>`).

  Accepts values like `96dpi`, `2dppx`.
  """
  @spec resolution(String.t()) :: property_type()
  def resolution(initial) do
    [syntax: "<resolution>", initial: initial, inherits: true]
  end

  @doc """
  Time type (`<time>`).

  Accepts values like `0ms`, `1s`, `300ms`.
  """
  @spec time(String.t()) :: property_type()
  def time(initial) do
    [syntax: "<time>", initial: initial, inherits: true]
  end

  @doc """
  Transform function type (`<transform-function>`).

  Accepts a single transform function like `rotate(45deg)`.
  """
  @spec transform_function(String.t()) :: property_type()
  def transform_function(initial) do
    [syntax: "<transform-function>", initial: initial, inherits: true]
  end

  @doc """
  Transform list type (`<transform-list>`).

  Accepts a list of transform functions.

  ## Examples

      Types.transform_list([
        Functions.rotate(Units.deg(45)),
        Functions.scale(1.5)
      ])
  """
  @spec transform_list(list(String.t())) :: property_type()
  def transform_list(transforms) when is_list(transforms) do
    [syntax: "<transform-list>", initial: Enum.join(transforms, " "), inherits: true]
  end

  @doc """
  URL type (`<url>`).

  Accepts URL values.
  """
  @spec url(String.t()) :: property_type()
  def url(initial) do
    [syntax: "<url>", initial: initial, inherits: true]
  end

  @doc """
  Custom identifier type (`<custom-ident>`).

  Accepts custom identifiers (unquoted strings).
  """
  @spec custom_ident(String.t()) :: property_type()
  def custom_ident(initial) do
    [syntax: "<custom-ident>", initial: initial, inherits: true]
  end

  @doc """
  String type (`<string>`).

  Accepts quoted string values.
  """
  @spec string(String.t()) :: property_type()
  def string(initial) do
    [syntax: "<string>", initial: "\"#{initial}\"", inherits: true]
  end

  @doc """
  Any type (`*`).

  Accepts any value. Note: properties with `*` syntax cannot be animated.
  """
  @spec any(String.t()) :: property_type()
  def any(initial) do
    [syntax: "*", initial: initial, inherits: true]
  end

  @doc """
  Creates a non-inheriting property type.

  By default, all properties inherit. Use this to create one that doesn't.

  ## Examples

      Types.length("0px") |> Types.no_inherit()
  """
  @spec no_inherit(property_type()) :: property_type()
  def no_inherit(property) do
    Keyword.put(property, :inherits, false)
  end

  @doc """
  Creates a property with a custom syntax.

  Use this for complex or union types.

  ## Examples

      Types.custom("<length> | auto", "auto")
  """
  @spec custom(String.t(), String.t() | number()) :: property_type()
  def custom(syntax, initial) do
    [syntax: syntax, initial: initial, inherits: true]
  end
end
