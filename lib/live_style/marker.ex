defmodule LiveStyle.Marker do
  @moduledoc """
  Marker class generation for contextual selectors.

  Markers are special CSS classes used with `LiveStyle.When` to create contextual
  selectors that style elements based on ancestor, descendant, or sibling state.

  ## Usage

  Use `LiveStyle.default_marker/0` or `LiveStyle.define_marker/1` from the main
  LiveStyle module, which delegates to this module.

  ## Example

      defmodule MyComponent do
        use Phoenix.Component
        use LiveStyle.Sheet
        alias LiveStyle.When

        css_class :card,
          transform: %{
            :default => "translateX(0)",
            When.ancestor(":hover") => "translateX(10px)"
          }

        def render(assigns) do
          ~H\"\"\"
          <div class={LiveStyle.default_marker()}>
            <div class={css_class(:card)}>Hover parent to move me</div>
          </div>
          \"\"\"
        end
      end

  ## Custom Markers

  For multiple independent sets of contextual selectors, use custom markers:

      @row_marker LiveStyle.define_marker(:row)
      @card_marker LiveStyle.define_marker(:card)

      css_class :cell,
        background: %{
          :default => "transparent",
          When.ancestor(":hover", @row_marker) => "#eee"
        }
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

      css_class :heading,
        transform: %{
          :default => "translateX(0)",
          When.ancestor(":hover", @card_marker) => "translateX(10px)"
        }
  """
  @spec define(atom()) :: String.t()
  def define(name) when is_atom(name) do
    Hash.marker_name(name)
  end
end
