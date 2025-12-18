defmodule LiveStyle.Shorthand.Strategy.RejectShorthands do
  @moduledoc """
  Rejects disallowed shorthand properties at compile time.

  This strategy raises compile-time errors for shorthand properties that
  are ambiguous or could cause cascade issues (like `border`, `background`,
  `animation`). Other shorthands like `margin`, `padding` pass through.

  Error messages are defined in `data/disallowed_shorthands.txt` to keep
  the data centralized and easily maintainable.

  ## Example

      # Allowed - passes through
      margin: "10px"  # => margin: "10px"

      # Disallowed - raises at compile time
      border: "1px solid black"  # => ArgumentError
  """

  @behaviour LiveStyle.Shorthand.Strategy

  @impl true
  def expand_declaration(key, value, opts) do
    css_property = LiveStyle.to_css_property(key)

    reject_if_disallowed!(css_property, opts)

    [{key, value}]
  end

  @impl true
  def expand_shorthand_conditions(key, css_property, conditions, opts) do
    reject_if_disallowed!(css_property, opts)

    [{key, conditions}]
  end

  defp reject_if_disallowed!(css_property, opts) do
    disallowed_shorthands = opts[:disallowed_shorthands] || MapSet.new()

    if MapSet.member?(disallowed_shorthands, css_property) do
      # Get the full error message from data file
      disallowed_with_messages = opts[:disallowed_shorthands_with_messages] || %{}

      message =
        Map.get(
          disallowed_with_messages,
          css_property,
          "'#{css_property}' is not supported. Use longhand properties instead."
        )

      raise ArgumentError, message
    end
  end
end
