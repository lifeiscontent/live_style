defmodule LiveStyle.ShorthandBehavior.ForbidShorthands do
  @moduledoc """
  Forbids disallowed shorthand properties at compile time.

  This behavior raises compile-time errors for shorthand properties that
  are ambiguous or could cause cascade issues (like `border`, `background`,
  `animation`). Other shorthands like `margin`, `padding` pass through.

  Error messages are defined in `data/disallowed_shorthands.txt` to keep
  the data centralized and easily maintainable.

  ## Example

      iex> ForbidShorthands.expand("margin", "10px")
      [{"margin", "10px"}]

      iex> ForbidShorthands.expand("border", "1px solid black")
      ** (ArgumentError) 'border' is not supported...

  """

  @behaviour LiveStyle.ShorthandBehavior

  alias LiveStyle.PropertyMetadata

  # Load data at compile time
  @disallowed_shorthands PropertyMetadata.disallowed_shorthands()
  @disallowed_shorthands_with_messages PropertyMetadata.disallowed_shorthands_with_messages()

  # ==========================================================================
  # Behavior Callbacks
  # ==========================================================================

  @impl true
  def expand_declaration(css_property, value, _opts) do
    forbid_if_disallowed!(css_property)
    [{css_property, value}]
  end

  @impl true
  def expand_shorthand_conditions(css_property, conditions, _opts) do
    forbid_if_disallowed!(css_property)
    [{css_property, conditions}]
  end

  # ==========================================================================
  # Validation
  # ==========================================================================

  # Generate forbid checks at compile time
  for property <- @disallowed_shorthands do
    message =
      case List.keyfind(@disallowed_shorthands_with_messages, property, 0) do
        {_, msg} -> msg
        nil -> "'#{property}' is not supported. Use longhand properties instead."
      end

    defp forbid_if_disallowed!(unquote(property)) do
      raise ArgumentError, unquote(message)
    end
  end

  # Default: allowed
  defp forbid_if_disallowed!(_), do: :ok
end
