defmodule LiveStyle.When do
  @moduledoc """
  Contextual selectors for styling elements based on ancestor, descendant, or sibling state.

  These functions generate CSS selectors that allow you to style an element based on
  the state of related elements in the DOM tree. They work by using marker classes
  that you apply to the elements you want to observe.

  ## Browser Support

  Some selectors (`sibling_after/2`, `any_sibling/2`, and `descendant/2`) rely on
  the CSS `:has()` selector. Check browser support at https://caniuse.com/css-has

  ## Using Markers

  To use these selectors, you must mark the element being observed with a marker class.
  Use `Marker.default/0` for the default marker, or `Marker.define/1` for custom markers.

  ## Example

      defmodule MyComponent do
        use LiveStyle.Sheet
        alias LiveStyle.When
        alias LiveStyle.Marker

        css_rule :card,
          transform: %{
            default: "translateX(0)",
            When.ancestor(":hover") => "translateX(10px)"
          }

        def render(assigns) do
          ~H\"\"\"
          <div class={Marker.default()}>
            <div class={css_class([:card])}>Hover parent to move me</div>
          </div>
          \"\"\"
        end
      end
  """

  alias LiveStyle.Marker

  @doc """
  Creates a selector that styles an element when an ancestor has the given pseudo-state.

  The selector matches when any ancestor with the marker class has the specified
  pseudo-class active (e.g., `:hover`, `:focus`).

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to the configured default marker.

  ## Example

      css_rule :item,
        opacity: %{
          default: "1",
          When.ancestor(":hover") => "0.5"
        }

  Generates CSS like: `.class:where(.{prefix}-default-marker:hover *) { opacity: 0.5; }`
  """
  def ancestor(pseudo), do: ancestor(pseudo, Marker.default())

  def ancestor(pseudo, marker) do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} *)"
  end

  @doc """
  Creates a selector that styles an element when a descendant has the given pseudo-state.

  The selector matches when any descendant with the marker class has the specified
  pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to the configured default marker.

  ## Example

      css_rule :container,
        border_color: %{
          default: "gray",
          When.descendant(":focus") => "blue"
        }

  Generates CSS like: `.class:where(:has(.{prefix}-default-marker:focus)) { border-color: blue; }`
  """
  def descendant(pseudo), do: descendant(pseudo, Marker.default())

  def descendant(pseudo, marker) do
    validate_pseudo!(pseudo)
    ":where(:has(.#{marker}#{pseudo}))"
  end

  @doc """
  Creates a selector that styles an element when a preceding sibling has the given pseudo-state.

  The selector matches when a sibling element that comes *before* this element
  in the DOM has the specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to the configured default marker.

  ## Example

      css_rule :item,
        background_color: %{
          default: "white",
          When.sibling_before(":hover") => "lightblue"
        }

  Generates CSS like: `.class:where(.{prefix}-default-marker:hover ~ *) { background-color: lightblue; }`
  """
  def sibling_before(pseudo), do: sibling_before(pseudo, Marker.default())

  def sibling_before(pseudo, marker) do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} ~ *)"
  end

  @doc """
  Creates a selector that styles an element when a following sibling has the given pseudo-state.

  The selector matches when a sibling element that comes *after* this element
  in the DOM has the specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to the configured default marker.

  ## Example

      css_rule :label,
        color: %{
          default: "black",
          When.sibling_after(":focus") => "blue"
        }

  Generates CSS like: `.class:where(:has(~ .{prefix}-default-marker:focus)) { color: blue; }`
  """
  def sibling_after(pseudo), do: sibling_after(pseudo, Marker.default())

  def sibling_after(pseudo, marker) do
    validate_pseudo!(pseudo)
    ":where(:has(~ .#{marker}#{pseudo}))"
  end

  @doc """
  Creates a selector that styles an element when any sibling has the given pseudo-state.

  The selector matches when any sibling element (before or after) has the
  specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to the configured default marker.

  ## Example

      css_rule :tab,
        opacity: %{
          default: "1",
          When.any_sibling(":hover") => "0.7"
        }

  Generates CSS like: `.class:where(.{prefix}-default-marker:hover ~ *, :has(~ .{prefix}-default-marker:hover)) { opacity: 0.7; }`
  """
  def any_sibling(pseudo), do: any_sibling(pseudo, Marker.default())

  def any_sibling(pseudo, marker) do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} ~ *, :has(~ .#{marker}#{pseudo}))"
  end

  defp validate_pseudo!(<<"::", _rest::binary>>) do
    raise ArgumentError, "Pseudo-elements (::) are not supported in contextual selectors"
  end

  defp validate_pseudo!(<<":", _rest::binary>>), do: :ok

  defp validate_pseudo!(pseudo) do
    raise ArgumentError, "Pseudo selector must start with ':' (got #{inspect(pseudo)})"
  end
end
