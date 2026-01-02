defmodule LiveStyle.Marker do
  @moduledoc """
  Marker class generation for contextual selectors.

  Markers are special CSS classes used with `LiveStyle.When` to create contextual
  selectors that style elements based on ancestor, descendant, or sibling state.

  ## Usage

  Use `LiveStyle.default_marker/0` or `LiveStyle.marker/1` from the main
  LiveStyle module.

  ## Example

      defmodule MyComponent do
        use Phoenix.Component
        use LiveStyle
        alias LiveStyle.When

        class :card,
          transform: [
            {:default, "translateX(0)"},
            {When.ancestor(":hover"), "translateX(10px)"}
          ]

        def render(assigns) do
          ~H\"\"\"
          <div {css(default_marker())}>
            <div {css(:card)}>Hover parent to move me</div>
          </div>
          \"\"\"
        end
      end

  ## Custom Markers

  For multiple independent sets of contextual selectors, use custom markers:

      class :cell,
        background: [
          {:default, "transparent"},
          {When.ancestor(":hover", marker(:row)), "#eee"}
        ]

      # In template:
      <tr {css(marker(:row))}>
        <td {css(:cell)}>...</td>
      </tr>

  ## Cross-Module Markers

  Use `{Module, :name}` syntax to reference markers from other modules:

      # In template:
      <tr {css(marker({OtherModule, :row}))}>

  Different modules using the same marker name get independent markers:

      # In ComponentA
      marker(:row)  # Different from ComponentB's :row

      # In ComponentB
      marker(:row)  # Different from ComponentA's :row
  """

  alias LiveStyle.{Config, Hash}

  @type t :: %__MODULE__{class: String.t()}
  defstruct [:class]

  # Identity-based CSS name generation (private)
  # Includes module for uniqueness, matching other LiveStyle APIs
  defp ident(module, name) do
    input = "marker:#{inspect(module)}.#{name}"
    Hash.class_prefix() <> Hash.create_hash(input)
  end

  @doc """
  Returns the default marker for use with `LiveStyle.When` selectors.

  This matches StyleX's `stylex.defaultMarker()` behavior.

  ## Example

      <div {css(default_marker())}>
        <div {css(:card)}>Hover parent to move me</div>
      </div>
  """
  @spec default() :: t()
  def default do
    %__MODULE__{class: "#{Config.class_name_prefix()}-default-marker"}
  end

  # Internal: use LiveStyle.marker/1 instead
  @doc false
  @spec ref({module(), atom()}) :: t()
  def ref({module, name}) when is_atom(module) and is_atom(name) do
    %__MODULE__{class: ident(module, name)}
  end

  @doc """
  Extracts the class string from a marker (struct or string).

  Used by `LiveStyle.When` to get the class name for CSS selectors.
  """
  @spec to_class(t() | String.t()) :: String.t()
  def to_class(%__MODULE__{class: class}), do: class
  def to_class(class) when is_binary(class), do: class
end
