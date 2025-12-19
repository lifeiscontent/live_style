defmodule LiveStyle.Class.SimpleProcessor do
  @moduledoc """
  Processes simple (non-conditional) CSS declarations into atomic classes.

  This module handles the expansion and processing of straightforward CSS property
  declarations like `%{display: "flex", padding: "8px"}`, converting them into
  atomic CSS classes with proper hashing and metadata.

  ## Responsibilities

  - Expanding shorthand properties via ShorthandBehavior
  - Handling nil values (StyleX unset markers)
  - Processing fallback values (arrays and first_that_works)
  - Generating atomic class entries with LTR/RTL metadata
  """

  alias LiveStyle.Class.CSS, as: ClassCSS
  alias LiveStyle.Class.Conditional
  alias LiveStyle.{Hash, Priority, Value}
  alias LiveStyle.ShorthandBehavior

  @doc """
  Processes a list of simple (non-conditional) declarations into atomic class entries.

  Returns a map of CSS property names to class entry maps containing:
  - `:class` - The generated class name
  - `:value` - The CSS value
  - `:ltr` - LTR CSS metadata
  - `:rtl` - RTL CSS metadata
  - `:priority` - Priority for ordering

  ## Example

      iex> process([{:display, "flex"}, {:padding, "8px"}])
      %{
        "display" => %{class: "x1234", value: "flex", ...},
        "padding" => %{class: "x5678", value: "8px", ...}
      }
  """
  @spec process(list()) :: map()
  def process(declarations) do
    # Convert keys to CSS strings at boundary, then expand shorthand properties
    expanded =
      declarations
      |> Enum.flat_map(fn {prop, value} ->
        css_prop = Value.to_css_property(prop)
        ShorthandBehavior.expand_declaration(css_prop, value)
      end)

    # Separate nil values from non-nil values
    # StyleX behavior: nil values don't generate CSS but mark the property as "unset"
    {nil_decls, non_nil_decls} = Enum.split_with(expanded, fn {_prop, value} -> is_nil(value) end)

    # Process nil declarations - store special marker for style merging
    nil_atomic = process_nil_declarations(nil_decls)

    # Process non-nil declarations
    non_nil_atomic = process_non_nil_declarations(non_nil_decls)

    # Merge nil_atomic (properties to unset) with non_nil_atomic
    # nil_atomic has priority as it represents explicit unsetting
    Map.merge(non_nil_atomic, nil_atomic)
  end

  # Process nil declarations - store special marker for style merging
  defp process_nil_declarations(nil_decls) do
    nil_decls
    |> Enum.map(fn {css_prop, _value} ->
      # Store a special marker indicating this property should be unset
      {css_prop, %{class: nil, null: true}}
    end)
    |> Map.new()
  end

  # Process non-nil declarations
  defp process_non_nil_declarations(declarations) do
    declarations
    |> Enum.map(fn {css_prop, value} ->
      # Handle fallback values (from css_fallback macro or plain lists)
      # StyleX treats arrays as fallback values: position: ['sticky', 'fixed']
      cond do
        match?(%{__fallback__: true, values: _}, value) ->
          # Explicit first_that_works() - applies reversal for non-var values
          %{__fallback__: true, values: values} = value
          process_first_that_works(css_prop, values)

        is_list(value) and is_plain_fallback_list?(value) ->
          # Plain list = fallback values (StyleX variableFallbacks behavior)
          # Arrays preserve order, only CSS vars get nested
          process_array_fallbacks(css_prop, value)

        true ->
          process_simple_value(css_prop, value)
      end
    end)
    |> Map.new()
  end

  # Process a simple CSS value (non-fallback, non-nil)
  defp process_simple_value(css_prop, value) do
    css_value = Value.to_css(value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value, nil, nil, nil)

    # Generate StyleX-compatible metadata
    {ltr_css, rtl_css} = ClassCSS.generate_metadata(class_name, css_prop, css_value, nil, nil)

    priority = Priority.calculate(css_prop, nil, nil)

    {css_prop,
     %{
       class: class_name,
       value: css_value,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end

  # Check if a list is a plain fallback list (not a conditional value list)
  # Conditional values are keyword lists like [default: "red", ":hover": "blue"]
  defp is_plain_fallback_list?(list) when is_list(list) do
    not Conditional.conditional?(list)
  end

  # Delegate fallback processing to the Fallback module
  defp process_array_fallbacks(css_prop, values) do
    LiveStyle.Fallback.process_array(css_prop, values)
  end

  defp process_first_that_works(css_prop, values) do
    LiveStyle.Fallback.process_first_that_works(css_prop, values)
  end
end
