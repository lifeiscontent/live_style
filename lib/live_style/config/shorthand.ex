defmodule LiveStyle.Config.Shorthand do
  @moduledoc """
  Configuration for CSS shorthand property handling.

  Controls how LiveStyle expands shorthand properties like `margin`, `padding`, etc.
  """

  alias LiveStyle.Config.Overrides

  @default_shorthand_behavior LiveStyle.ShorthandBehavior.AcceptShorthands

  @atom_to_behavior_module %{
    accept_shorthands: LiveStyle.ShorthandBehavior.AcceptShorthands,
    flatten_shorthands: LiveStyle.ShorthandBehavior.FlattenShorthands,
    forbid_shorthands: LiveStyle.ShorthandBehavior.ForbidShorthands
  }

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
  @spec shorthand_behavior() :: {module(), keyword()}
  def shorthand_behavior do
    value =
      Overrides.get(:shorthand_behavior) ||
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
end
