defmodule LiveStyle.Shorthand.Strategy.KeepShorthands do
  @moduledoc """
  Keeps shorthand properties intact with null resets for longhands.

  This is the default strategy. Shorthand properties are preserved,
  but conflicting longhand properties are reset to `nil` to ensure
  deterministic cascade behavior.

  The last style wins when merging, similar to how CSS cascade works.

  ## Example

      # Input
      margin: "10px 20px"

      # Output keeps the shorthand
      margin: "10px 20px"
  """

  @behaviour LiveStyle.Shorthand.Strategy

  alias LiveStyle.Shorthand.Strategy

  @impl true
  def expand_declaration(key, value, opts) do
    css_property = LiveStyle.to_css_property(key)

    case Strategy.get_expansion_fn(css_property, opts) do
      nil ->
        Strategy.passthrough(key, value)

      expansion_fn ->
        LiveStyle.Shorthand
        |> apply(expansion_fn, [value])
        |> Enum.reject(fn {_prop, val} -> is_nil(val) end)
    end
  end

  @impl true
  def expand_shorthand_conditions(key, css_property, conditions, opts) do
    case Strategy.get_expansion_fn(css_property, opts) do
      nil ->
        Strategy.passthrough_conditions(key, conditions)

      expansion_fn ->
        expanded_props = Strategy.get_expanded_property_names(expansion_fn)
        expanded_conditions = Strategy.expand_conditions_map(conditions, expansion_fn)

        expanded_props
        |> Enum.map(&{&1, Map.get(expanded_conditions, &1)})
        |> Enum.reject(fn {_prop, val} -> is_nil(val) or val == %{} end)
    end
  end
end
