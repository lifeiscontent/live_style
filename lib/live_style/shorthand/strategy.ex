defmodule LiveStyle.Shorthand.Strategy do
  @moduledoc """
  Behaviour and dispatch for shorthand expansion strategies.

  LiveStyle supports three built-in strategies for handling CSS shorthand properties:

  - `LiveStyle.Shorthand.Strategy.KeepShorthands` (default) - Keeps shorthand properties with null resets
  - `LiveStyle.Shorthand.Strategy.ExpandToLonghands` - Expands shorthands to their longhand equivalents
  - `LiveStyle.Shorthand.Strategy.RejectShorthands` - Rejects disallowed shorthand properties at compile time

  You can also provide a custom module that implements this behaviour.

  ## Configuration

      # Using atom shortcuts
      config :live_style,
        shorthand_strategy: :keep_shorthands

      # Using module directly
      config :live_style,
        shorthand_strategy: LiveStyle.Shorthand.Strategy.ExpandToLonghands

      # Custom strategy with options
      config :live_style,
        shorthand_strategy: {MyCustomStrategy, strict: true}
  """

  @callback expand_declaration(atom(), any(), map()) :: [{atom(), any()}]
  @callback expand_shorthand_conditions(atom(), String.t(), map(), map()) :: [{atom(), any()}]

  # ===========================================================================
  # Backend Dispatch
  # ===========================================================================

  @doc """
  Returns the configured strategy module and options.

  Returns a tuple of `{module, opts}`.
  """
  def backend do
    LiveStyle.Config.shorthand_strategy()
  end

  @doc """
  Returns just the configured strategy module.
  """
  def backend_module do
    {module, _opts} = backend()
    module
  end

  @doc """
  Returns the standard options map for shorthand expansion.

  This centralizes the options construction so callers don't need to
  build it themselves.
  """
  def opts do
    %{
      shorthand_expansions: LiveStyle.Data.shorthand_expansions(),
      disallowed_shorthands: LiveStyle.Data.disallowed_shorthands(),
      disallowed_shorthands_with_messages: LiveStyle.Data.disallowed_shorthands_with_messages()
    }
  end

  @doc """
  Expands a declaration using the configured strategy.
  """
  def expand_declaration(key, value, expansion_opts \\ nil) do
    expansion_opts = expansion_opts || opts()
    backend_module().expand_declaration(key, value, expansion_opts)
  end

  @doc """
  Expands shorthand conditions using the configured strategy.
  """
  def expand_shorthand_conditions(key, css_property, conditions, expansion_opts \\ nil) do
    expansion_opts = expansion_opts || opts()
    backend_module().expand_shorthand_conditions(key, css_property, conditions, expansion_opts)
  end

  # ===========================================================================
  # Shared Helpers (used by strategy implementations)
  # ===========================================================================

  @doc false
  def get_expansion_fn(css_property, opts) do
    shorthand_expansions = opts[:shorthand_expansions] || %{}
    Map.get(shorthand_expansions, css_property)
  end

  @doc false
  def passthrough(key, value), do: [{key, value}]

  @doc false
  def passthrough_conditions(key, conditions), do: [{key, conditions}]

  @doc false
  def expand_conditions_map(conditions, expansion_fn) do
    Enum.reduce(conditions, %{}, fn {condition, value}, acc ->
      expanded = apply(LiveStyle.Shorthand, expansion_fn, [value])

      Enum.reduce(expanded, acc, fn {prop, val}, inner_acc ->
        if is_nil(val) do
          inner_acc
        else
          prop_conditions = Map.get(inner_acc, prop, %{})
          Map.put(inner_acc, prop, Map.put(prop_conditions, condition, val))
        end
      end)
    end)
  end

  @doc false
  def get_expanded_property_names(expansion_fn) do
    apply(LiveStyle.Shorthand, expansion_fn, ["sample"])
    |> Enum.map(fn {prop, _} -> prop end)
  end
end
