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
  Use `LiveStyle.default_marker/0` for the default marker, or define custom markers
  with `LiveStyle.define_marker/1`.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        import LiveStyle.When

        style(:card, %{
          transform: %{
            default: "translateX(0)",
            ancestor(":hover"): "translateX(10px)"
          }
        })

        def render(assigns) do
          ~H\"\"\"
          <div class={LiveStyle.default_marker()}>
            <div class={style(:card)}>Hover parent to move me</div>
          </div>
          \"\"\"
        end
      end
  """

  @doc """
  Creates a selector that styles an element when an ancestor has the given pseudo-state.

  The selector matches when any ancestor with the marker class has the specified
  pseudo-class active (e.g., `:hover`, `:focus`).

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to `"x-marker"`.

  ## Example

      style(:item, %{
        opacity: %{
          default: "1",
          ancestor(":hover"): "0.5"
        }
      })

  Generates CSS like: `.class:where(.x-marker:hover *) { opacity: 0.5; }`
  """
  def ancestor(pseudo, marker \\ "x-marker") do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} *)"
  end

  @doc """
  Creates a selector that styles an element when a descendant has the given pseudo-state.

  The selector matches when any descendant with the marker class has the specified
  pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to `"x-marker"`.

  ## Example

      style(:container, %{
        border_color: %{
          default: "gray",
          descendant(":focus"): "blue"
        }
      })

  Generates CSS like: `.class:where(:has(.x-marker:focus)) { border-color: blue; }`
  """
  def descendant(pseudo, marker \\ "x-marker") do
    validate_pseudo!(pseudo)
    ":where(:has(.#{marker}#{pseudo}))"
  end

  @doc """
  Creates a selector that styles an element when a preceding sibling has the given pseudo-state.

  The selector matches when a sibling element that comes *before* this element
  in the DOM has the specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to `"x-marker"`.

  ## Example

      style(:item, %{
        background_color: %{
          default: "white",
          sibling_before(":hover"): "lightblue"
        }
      })

  Generates CSS like: `.class:where(.x-marker:hover ~ *) { background-color: lightblue; }`
  """
  def sibling_before(pseudo, marker \\ "x-marker") do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} ~ *)"
  end

  @doc """
  Creates a selector that styles an element when a following sibling has the given pseudo-state.

  The selector matches when a sibling element that comes *after* this element
  in the DOM has the specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to `"x-marker"`.

  ## Example

      style(:label, %{
        color: %{
          default: "black",
          sibling_after(":focus"): "blue"
        }
      })

  Generates CSS like: `.class:where(:has(~ .x-marker:focus)) { color: blue; }`
  """
  def sibling_after(pseudo, marker \\ "x-marker") do
    validate_pseudo!(pseudo)
    ":where(:has(~ .#{marker}#{pseudo}))"
  end

  @doc """
  Creates a selector that styles an element when any sibling has the given pseudo-state.

  The selector matches when any sibling element (before or after) has the
  specified pseudo-class active.

  ## Parameters

    * `pseudo` - The pseudo selector (e.g., `":hover"`, `":focus"`)
    * `marker` - Optional custom marker class name. Defaults to `"x-marker"`.

  ## Example

      style(:tab, %{
        opacity: %{
          default: "1",
          any_sibling(":hover"): "0.7"
        }
      })

  Generates CSS like: `.class:where(.x-marker:hover ~ *, :has(~ .x-marker:hover)) { opacity: 0.7; }`
  """
  def any_sibling(pseudo, marker \\ "x-marker") do
    validate_pseudo!(pseudo)
    ":where(.#{marker}#{pseudo} ~ *, :has(~ .#{marker}#{pseudo}))"
  end

  defp validate_pseudo!(pseudo) do
    unless String.starts_with?(pseudo, ":") do
      raise ArgumentError, "Pseudo selector must start with ':' (got #{inspect(pseudo)})"
    end

    if String.starts_with?(pseudo, "::") do
      raise ArgumentError, "Pseudo-elements (::) are not supported in When selectors"
    end
  end
end
