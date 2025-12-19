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
      [{:margin, "10px"}]

      iex> ForbidShorthands.expand("border", "1px solid black")
      ** (ArgumentError) 'border' is not supported...

  """

  @behaviour LiveStyle.ShorthandBehavior

  alias LiveStyle.Data

  # Load data at compile time
  @disallowed_shorthands Data.disallowed_shorthands()
  @disallowed_shorthands_with_messages Data.disallowed_shorthands_with_messages()

  # ==========================================================================
  # Public API
  # ==========================================================================

  @doc """
  Expands a CSS property and value according to the ForbidShorthands behavior.

  Raises `ArgumentError` for disallowed shorthand properties.
  For allowed properties, returns the property unchanged.

  ## Examples

      iex> ForbidShorthands.expand("margin", "10px")
      [{:margin, "10px"}]

      iex> ForbidShorthands.expand("border", "1px solid black")
      ** (ArgumentError) 'border' is not supported. Use border-width, border-style, and border-color instead.

  """
  def expand(css_property, value) when is_binary(css_property) do
    forbid_if_disallowed!(css_property)
    [{css_to_atom(css_property), value}]
  end

  # ==========================================================================
  # Behavior Callbacks
  # ==========================================================================

  @impl true
  def expand_declaration(key, value, _opts) do
    css_property = to_css_property(key)
    expand(css_property, value)
  end

  @impl true
  def expand_shorthand_conditions(key, css_property, conditions, _opts) do
    forbid_if_disallowed!(css_property)
    [{key, conditions}]
  end

  # ==========================================================================
  # Validation
  # ==========================================================================

  # Generate forbid checks at compile time
  for property <- @disallowed_shorthands do
    message =
      Map.get(
        @disallowed_shorthands_with_messages,
        property,
        "'#{property}' is not supported. Use longhand properties instead."
      )

    defp forbid_if_disallowed!(unquote(property)) do
      raise ArgumentError, unquote(message)
    end
  end

  # Default: allowed
  defp forbid_if_disallowed!(_), do: :ok

  # ==========================================================================
  # Utility Functions
  # ==========================================================================

  defp css_to_atom(css_property) do
    css_property
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp to_css_property(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp to_css_property(key) when is_binary(key), do: key
end
