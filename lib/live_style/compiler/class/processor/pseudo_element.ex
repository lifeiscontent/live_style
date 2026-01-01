defmodule LiveStyle.Compiler.Class.Processor.PseudoElement do
  @moduledoc """
  Processes pseudo-element CSS declarations into atomic classes.

  This module handles declarations for pseudo-elements like `::before` and `::after`.
  For example: `%{"::after": %{content: "''", display: "block"}}`

  It also handles conditional values within pseudo-elements:
  `%{"::before": %{color: %{:default => "red", ":hover" => "blue"}}}`

  ## Responsibilities

  - Detecting and extracting pseudo-element declarations
  - Processing nested properties within pseudo-elements
  - Handling conditional values within pseudo-elements
  - Generating atomic class entries with pseudo-element selectors
  """

  alias LiveStyle.Compiler.Class.{Builder, Conditional}
  alias LiveStyle.CSSValue

  @doc """
  Processes a list of pseudo-element declarations into atomic class entries.

  Returns a map where each key is a combination of CSS property and pseudo-element
  selector, mapping to the class entry.

  ## Example

      iex> process([{"::after", %{content: "''", display: "block"}}])
      %{
        "content::after" => %{class: "x1234", value: "''", ...},
        "display::after" => %{class: "x5678", value: "block", ...}
      }
  """
  @spec process(list(), keyword()) :: map()
  def process(declarations, _opts \\ []) do
    declarations
    |> Enum.flat_map(fn {pseudo_element, props_map} ->
      process_props(to_string(pseudo_element), props_map)
    end)
    |> Map.new()
  end

  # Process all properties within a pseudo-element
  defp process_props(pseudo_str, props_map) do
    Enum.flat_map(props_map, fn {prop, value} ->
      process_prop(pseudo_str, prop, value)
    end)
  end

  # Process a single property within a pseudo-element
  defp process_prop(pseudo_str, prop, value) do
    css_prop = CSSValue.to_css_property(prop)

    if Conditional.conditional?(value) do
      process_conditional_prop(pseudo_str, css_prop, value)
    else
      process_simple_prop(pseudo_str, css_prop, value)
    end
  end

  # Process a conditional property within a pseudo-element
  # e.g., "::before": %{color: %{:default => "red", ":hover" => "blue"}}
  defp process_conditional_prop(pseudo_str, css_prop, value) do
    value
    |> Conditional.flatten(nil)
    |> Enum.map(fn {selector, css_val} ->
      full_selector = build_full_selector(pseudo_str, selector)
      build_class_entry(css_prop, css_val, full_selector)
    end)
  end

  # Process a simple (non-conditional) property within a pseudo-element
  defp process_simple_prop(pseudo_str, css_prop, value) do
    [build_class_entry(css_prop, value, pseudo_str)]
  end

  # Build the full selector combining pseudo-element and optional condition
  defp build_full_selector(pseudo_str, nil), do: pseudo_str
  defp build_full_selector(pseudo_str, selector), do: pseudo_str <> selector

  # Build a class entry for a pseudo-element property
  defp build_class_entry(css_prop, value, selector) do
    entry = Builder.build(css_prop, value, selector: selector)
    {"#{css_prop}#{selector}", Map.put(entry, :pseudo_element, selector)}
  end
end
