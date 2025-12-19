defmodule LiveStyle.ShorthandBehavior do
  @moduledoc """
  Behaviour and dispatch for shorthand expansion.

  LiveStyle supports three built-in behaviors for handling CSS shorthand properties:

  - `LiveStyle.ShorthandBehavior.AcceptShorthands` (default) - Keeps shorthand properties with null resets
  - `LiveStyle.ShorthandBehavior.FlattenShorthands` - Expands shorthands to their longhand equivalents
  - `LiveStyle.ShorthandBehavior.ForbidShorthands` - Forbids disallowed shorthand properties at compile time

  You can also provide a custom module that implements this behaviour.

  ## Configuration

      # Using atom shortcuts
      config :live_style,
        shorthand_behavior: :accept_shorthands

      # Using module directly
      config :live_style,
        shorthand_behavior: LiveStyle.ShorthandBehavior.FlattenShorthands

      # Custom behavior with options
      config :live_style,
        shorthand_behavior: {MyCustomBehavior, strict: true}

  ## Implementing a Custom Behavior

  To implement a custom behavior, create a module that implements the
  `LiveStyle.ShorthandBehavior` behaviour. Property keys are CSS strings
  (e.g., `"margin-top"`, `"background-color"`).

      defmodule MyCustomBehavior do
        @behaviour LiveStyle.ShorthandBehavior

        @impl true
        def expand_declaration(css_property, value, opts) do
          # Return list of {css_property_string, value} tuples
          [{css_property, value}]
        end

        @impl true
        def expand_shorthand_conditions(css_property, conditions, opts) do
          # Return list of {css_property_string, conditions_map} tuples
          [{css_property, conditions}]
        end
      end
  """

  @callback expand_declaration(String.t(), any(), map()) :: [{String.t(), any()}]
  @callback expand_shorthand_conditions(String.t(), map(), map()) :: [{String.t(), any()}]

  @doc """
  Returns the configured behavior module and options.

  Returns a tuple of `{module, opts}`.
  """
  def backend do
    LiveStyle.Config.shorthand_behavior()
  end

  @doc """
  Returns just the configured behavior module.
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
      shorthand_properties: LiveStyle.Data.shorthand_properties(),
      disallowed_shorthands: LiveStyle.Data.disallowed_shorthands(),
      disallowed_shorthands_with_messages: LiveStyle.Data.disallowed_shorthands_with_messages()
    }
  end

  @doc """
  Expands a declaration using the configured behavior.

  Takes a CSS property string (e.g., `"margin"`, `"background-color"`) and value.
  Returns a list of `{css_property_string, value}` tuples.
  """
  def expand_declaration(css_property, value, expansion_opts \\ nil) do
    expansion_opts = expansion_opts || opts()
    backend_module().expand_declaration(css_property, value, expansion_opts)
  end

  @doc """
  Expands shorthand conditions using the configured behavior.

  Takes a CSS property string and a conditions map.
  Returns a list of `{css_property_string, conditions_map}` tuples.
  """
  def expand_shorthand_conditions(css_property, conditions, expansion_opts \\ nil) do
    expansion_opts = expansion_opts || opts()
    backend_module().expand_shorthand_conditions(css_property, conditions, expansion_opts)
  end
end
