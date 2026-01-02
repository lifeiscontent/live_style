defmodule LiveStyle.Class.Processor.Simple do
  @moduledoc """
  Processes simple (non-conditional) CSS declarations into atomic classes.

  This module handles the expansion and processing of straightforward CSS property
  declarations like `[display: "flex", padding: "8px"]`, converting them into
  atomic CSS classes with proper hashing and metadata.

  ## Responsibilities

  - Expanding shorthand properties via ShorthandBehavior
  - Handling nil values (StyleX unset markers)
  - Processing fallback values (arrays and fallback)
  - Generating atomic class entries with component parts for CSS generation
  """

  alias LiveStyle.Class.{Builder, Conditional}
  alias LiveStyle.Config
  alias LiveStyle.CSSValue
  alias LiveStyle.Property.Validation
  alias LiveStyle.ShorthandBehavior
  alias LiveStyle.Utils

  @doc """
  Processes a list of simple (non-conditional) declarations into atomic class entries.

  Returns a list of `{css_prop, entry}` tuples containing:
  - `:class` - The generated class name
  - `:value` - The CSS value
  - `:priority` - Priority for ordering
  - `:selector_suffix` - Optional selector suffix
  - `:at_rule` - Optional at-rule

  LTR/RTL CSS is regenerated on demand during CSS rendering.

  ## Options

  - `:file` - Source file path for validation warnings
  - `:line` - Source line number for validation warnings

  ## Example

      iex> transform([{:display, "flex"}, {:padding, "8px"}])
      [
        {"display", [class: "x1234", value: "flex", priority: 3000]},
        {"padding", [class: "x5678", value: "8px", priority: 3000]}
      ]
  """
  @spec transform(list(), keyword()) :: list()
  def transform(declarations, opts \\ []) do
    # Convert keys to CSS strings at boundary, validate, then expand shorthand properties
    expanded =
      declarations
      |> Enum.flat_map(fn {prop, value} ->
        css_prop = CSSValue.to_css_property(prop)
        maybe_validate_property(css_prop, opts)
        ShorthandBehavior.expand_declaration(css_prop, value)
      end)

    # Separate nil values from non-nil values
    # StyleX behavior: nil values don't generate CSS but mark the property as "unset"
    {nil_decls, non_nil_decls} = Enum.split_with(expanded, fn {_prop, value} -> is_nil(value) end)

    # Process nil declarations - store special marker for style merging
    nil_atomic = process_nil_declarations(nil_decls)

    # Process non-nil declarations
    non_nil_atomic = process_non_nil_declarations(non_nil_decls)

    # Merge: non_nil first, then nil_atomic overrides (represents explicit unsetting)
    Utils.merge_declarations(non_nil_atomic, nil_atomic)
  end

  # Process nil declarations - store special marker for style merging
  defp process_nil_declarations(nil_decls) do
    # Store a special marker indicating these properties should be unset
    Enum.map(nil_decls, fn {css_prop, _value} ->
      {css_prop, [class: nil, unset: true]}
    end)
  end

  # Process non-nil declarations
  defp process_non_nil_declarations(declarations) do
    Enum.map(declarations, fn {css_prop, value} ->
      # Handle fallback values (from css_fallback macro or plain lists)
      # StyleX treats arrays as fallback values: position: ['sticky', 'fixed']
      cond do
        match?({:__fallback__, _}, value) ->
          # Explicit fallback() - applies reversal for non-var values
          {:__fallback__, values} = value
          transform_fallback(css_prop, values)

        is_list(value) and is_plain_fallback_list?(value) ->
          # Plain list = fallback values (StyleX variableFallbacks behavior)
          # Arrays preserve order, only CSS vars get nested
          transform_array_fallbacks(css_prop, value)

        true ->
          process_simple_value(css_prop, value)
      end
    end)
  end

  # Process a simple CSS value (non-fallback, non-nil)
  defp process_simple_value(css_prop, value) do
    {css_prop, Builder.create_entry(css_prop, value)}
  end

  # Check if a list is a plain fallback list (not a conditional value list)
  # Conditional values are keyword lists (e.g. [":hover": "blue", default: "red"]).
  defp is_plain_fallback_list?(list) when is_list(list) do
    not Conditional.conditional?(list)
  end

  # Delegate fallback processing to the Fallback module
  alias LiveStyle.Class.Fallback

  defp transform_array_fallbacks(css_prop, values) do
    Fallback.transform_array(css_prop, values)
  end

  defp transform_fallback(css_prop, values) do
    Fallback.transform_fallback(css_prop, values)
  end

  # Validate property name if validation is enabled
  defp maybe_validate_property(css_prop, opts) do
    if Config.validate_properties?() do
      Validation.validate!(css_prop, opts)
    end
  end
end
