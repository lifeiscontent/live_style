defmodule LiveStyle.Marker do
  @moduledoc """
  Marker class generation for contextual selectors.
  """

  alias LiveStyle.{Config, Hash}

  @doc """
  Returns the default marker class name for use with `LiveStyle.When` selectors.

  The marker name is derived from the configured `class_name_prefix` (default: "x"),
  producing `"{prefix}-default-marker"`.

  This matches StyleX's `stylex.defaultMarker()` behavior.

  ## Example

      ~H\"\"\"
      <div class={Marker.default()}>
        <div class={css_class([:card])}>Hover parent to move me</div>
      </div>
      \"\"\"
  """
  @spec default() :: String.t()
  def default do
    "#{Config.class_name_prefix()}-default-marker"
  end

  @doc """
  Generates a unique marker class name for use with `LiveStyle.When` selectors.

  Custom markers allow you to have multiple independent sets of contextual selectors
  in the same component tree.

  ## Parameters

    * `name` - An atom identifying this marker

  ## Example

      @card_marker Marker.define(:card)
      @row_marker Marker.define(:row)

      css_rule :heading,
        transform: %{
          default: "translateX(0)",
          When.ancestor(":hover", @card_marker) => "translateX(10px)"
        }
  """
  @spec define(atom()) :: String.t()
  def define(name) when is_atom(name) do
    Hash.marker_name(name)
  end
end
