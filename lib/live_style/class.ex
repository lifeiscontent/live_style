defmodule LiveStyle.Class do
  @moduledoc """
  Style class definition and processing for LiveStyle.

  This is an internal module that handles the processing of `css_class/2` declarations.
  You typically don't use this module directly - instead use `LiveStyle.Sheet` with
  the `css_class/2` macro.

  ## Responsibilities

  - Defining static and dynamic style classes
  - Processing declarations into atomic CSS classes
  - Handling conditional values (pseudo-classes, media queries)
  - Processing pseudo-element declarations
  - Applying shorthand expansion strategies

  ## Internal API Example

      # Static class (called by css_class macro)
      LiveStyle.Class.define(MyModule, :button, %{display: "flex", padding: "8px"})

      # Dynamic class
      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])

      # Lookup
      LiveStyle.Class.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """

  alias LiveStyle.Class.Conditional
  alias LiveStyle.Class.CSS, as: ClassCSS
  alias LiveStyle.Class.Selector
  alias LiveStyle.{Hash, Include, Manifest, Priority, Value}
  alias LiveStyle.MediaQuery.Transform, as: MediaQueryTransform
  alias LiveStyle.ShorthandBehavior

  @doc """
  Defines a static style class.

  ## Parameters

    * `module` - The module defining the class
    * `name` - The class name (atom)
    * `declarations` - Map of CSS property declarations

  ## Example

      LiveStyle.Class.define(MyModule, :button, %{display: "flex"})
  """
  @spec define(module(), atom(), map()) :: :ok
  def define(module, name, declarations) do
    key = Manifest.simple_key(module, name)

    # Resolve __include__ entries first
    resolved_declarations = Include.resolve(declarations, module)

    # Process declarations into atomic classes
    {atomic_classes, class_string} = process_declarations(resolved_declarations)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: resolved_declarations,
      dynamic: false
    }

    # Only update if the entry has changed (or doesn't exist)
    # This avoids unnecessary writes during test parallel loading while
    # still updating when source code changes in development
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_class(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_class(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Defines a dynamic style class.

  Dynamic classes use CSS variables that are set at runtime via inline styles.

  ## Parameters

    * `module` - The module defining the class
    * `name` - The class name (atom)
    * `all_props` - List of all CSS properties in the class
    * `param_names` - List of parameter names for the dynamic function

  ## Example

      LiveStyle.Class.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])
  """
  @spec define_dynamic(module(), atom(), [atom()], [atom()]) :: :ok
  def define_dynamic(module, name, all_props, param_names) do
    key = Manifest.simple_key(module, name)

    # For dynamic rules, generate CSS classes that use var(--x-prop) references
    # The actual values are set at runtime via inline styles
    {atomic_classes, class_string} = process_dynamic_declarations(all_props)

    entry = %{
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props,
      param_names: param_names,
      dynamic: true
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_class(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_class(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Looks up a class by module and name.

  Returns the class entry or raises if not found.

  ## Examples

      LiveStyle.Class.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """
  @spec lookup!(module(), atom()) :: map()
  def lookup!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      nil ->
        raise ArgumentError, """
        Unknown class: #{inspect(module)}.#{name}

        Make sure #{inspect(module)} is compiled before this module.
        """

      entry ->
        entry
    end
  end

  @doc false
  def process_declarations(declarations) do
    # Separate into: simple values, conditional values, and pseudo-element declarations
    {pseudo_decls, rest} =
      Enum.split_with(declarations, fn {prop, _value} ->
        LiveStyle.Pseudo.element?(prop)
      end)

    {simple_decls, conditional_decls} =
      rest
      |> Enum.split_with(fn {_prop, value} ->
        not conditional_value?(value)
      end)

    # Process simple declarations
    simple_atomic = process_simple_declarations(simple_decls)

    # Process conditional declarations
    conditional_atomic = process_conditional_declarations(conditional_decls)

    # Process pseudo-element declarations
    pseudo_atomic = process_pseudo_element_declarations(pseudo_decls)

    # Merge all atomic classes
    atomic =
      simple_atomic
      |> Map.merge(conditional_atomic)
      |> Map.merge(pseudo_atomic)

    class_string =
      atomic
      |> Map.values()
      |> Enum.flat_map(fn
        %{class: class} -> [class]
        %{classes: classes} -> Enum.map(Map.values(classes), & &1.class)
      end)
      |> Enum.join(" ")

    {atomic, class_string}
  end

  # Delegate conditional value detection to the Conditional module
  defp conditional_value?(value), do: Conditional.conditional?(value)

  defp process_simple_declarations(declarations) do
    # Expand shorthand properties based on style resolution mode
    expanded =
      declarations
      |> Enum.flat_map(fn {prop, value} ->
        ShorthandBehavior.expand_declaration(prop, value)
      end)

    # Separate nil values from non-nil values
    # StyleX behavior: nil values don't generate CSS but mark the property as "unset"
    {nil_decls, non_nil_decls} = Enum.split_with(expanded, fn {_prop, value} -> is_nil(value) end)

    # Process nil declarations - store special marker for style merging
    nil_atomic =
      nil_decls
      |> Enum.map(fn {prop, _value} ->
        css_prop = Value.to_css_property(prop)
        # Store a special marker indicating this property should be unset
        {css_prop, %{class: nil, null: true}}
      end)
      |> Map.new()

    expanded = non_nil_decls

    non_nil_atomic =
      expanded
      |> Enum.map(fn {prop, value} ->
        css_prop = Value.to_css_property(prop)

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
            # Use Value.to_css to apply StyleX normalizations (leading zeros, timings, etc.)
            css_value = Value.to_css(value, css_prop)
            class_name = Hash.atomic_class(css_prop, css_value, nil, nil, nil)

            # Generate StyleX-compatible metadata
            {ltr_css, rtl_css} =
              ClassCSS.generate_metadata(class_name, css_prop, css_value, nil, nil)

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
      end)
      |> Map.new()

    # Merge nil_atomic (properties to unset) with non_nil_atomic
    # nil_atomic has priority as it represents explicit unsetting
    Map.merge(non_nil_atomic, nil_atomic)
  end

  # Check if a list is a plain fallback list (not a conditional value list)
  # Conditional values are keyword lists like [default: "red", ":hover": "blue"]
  defp is_plain_fallback_list?(list) when is_list(list) do
    not conditional_value?(list)
  end

  # Delegate fallback processing to the Fallback module
  defp process_array_fallbacks(css_prop, values) do
    LiveStyle.Fallback.process_array(css_prop, values)
  end

  defp process_first_that_works(css_prop, values) do
    LiveStyle.Fallback.process_first_that_works(css_prop, values)
  end

  defp process_conditional_declarations(declarations) do
    declarations
    |> Enum.flat_map(fn {prop, value_map} ->
      css_prop = Value.to_css_property(prop)

      # Use style resolution for conditional properties
      ShorthandBehavior.expand_shorthand_conditions(prop, css_prop, value_map)
    end)
    |> Enum.flat_map(&process_expanded_conditional/1)
    |> Map.new()
  end

  defp process_expanded_conditional({prop, value_map}) do
    css_prop = Value.to_css_property(prop)

    # Apply StyleX's "last media query wins" transformation
    transformed_value_map = MediaQueryTransform.transform(value_map)

    # Flatten nested conditional maps into a list of {selector, value} tuples
    flattened = flatten_conditional_value(transformed_value_map, nil)

    # Process each flattened condition
    classes =
      flattened
      |> Enum.reject(fn {_selector, v} -> is_nil(v) end)
      |> Enum.map(fn {selector, css_value} ->
        build_conditional_class_entry(css_prop, selector, css_value)
      end)
      |> Map.new()

    [{css_prop, %{classes: classes}}]
  end

  # Build a class entry for conditional styles (with selector or at-rule)
  defp build_conditional_class_entry(css_prop, nil, css_value) do
    # Default value - no selector suffix
    css_value_str = Value.to_css(css_value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value_str, nil, nil, nil)
    {ltr_css, rtl_css} = ClassCSS.generate_metadata(class_name, css_prop, css_value_str, nil, nil)
    priority = Priority.calculate(css_prop, nil, nil)

    {:default,
     %{
       class: class_name,
       value: css_value_str,
       selector_suffix: nil,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end

  defp build_conditional_class_entry(css_prop, selector, css_value) do
    css_value_str = Value.to_css(css_value, css_prop)
    {selector_suffix, at_rule} = parse_combined_selector(selector)
    class_name = Hash.atomic_class(css_prop, css_value_str, nil, selector_suffix, at_rule)

    {ltr_css, rtl_css} =
      ClassCSS.generate_metadata(class_name, css_prop, css_value_str, selector_suffix, at_rule)

    priority = Priority.calculate(css_prop, selector_suffix, at_rule)

    {selector,
     %{
       class: class_name,
       value: css_value_str,
       selector_suffix: selector_suffix,
       at_rule: at_rule,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end

  # Delegate conditional value flattening to the Conditional module
  defp flatten_conditional_value(value, parent_selector) do
    Conditional.flatten(value, parent_selector)
  end

  # Delegate selector parsing to the Selector module
  defp parse_combined_selector(selector), do: Selector.parse_combined(selector)

  # Process pseudo-element declarations like "::after": %{content: "''", display: "block"}
  # Also handles conditional values within pseudo-elements like "::before": [color: {:":hover", "blue"}]
  defp process_pseudo_element_declarations(declarations) do
    declarations
    |> Enum.flat_map(fn {pseudo_element, props_map} ->
      process_pseudo_props(to_string(pseudo_element), props_map)
    end)
    |> Map.new()
  end

  defp process_pseudo_props(pseudo_str, props_map) do
    Enum.flat_map(props_map, fn {prop, value} ->
      process_pseudo_prop(pseudo_str, prop, value)
    end)
  end

  defp process_pseudo_prop(pseudo_str, prop, value) do
    css_prop = Value.to_css_property(prop)

    if conditional_value?(value) do
      process_conditional_pseudo_prop(pseudo_str, css_prop, value)
    else
      process_simple_pseudo_prop(pseudo_str, css_prop, value)
    end
  end

  defp process_conditional_pseudo_prop(pseudo_str, css_prop, value) do
    value
    |> flatten_conditional_value(nil)
    |> Enum.map(fn {selector, css_val} ->
      full_selector = build_full_selector(pseudo_str, selector)
      build_pseudo_class_entry(css_prop, css_val, full_selector)
    end)
  end

  defp process_simple_pseudo_prop(pseudo_str, css_prop, value) do
    [build_pseudo_class_entry(css_prop, value, pseudo_str)]
  end

  defp build_full_selector(pseudo_str, nil), do: pseudo_str
  defp build_full_selector(pseudo_str, selector), do: pseudo_str <> selector

  defp build_pseudo_class_entry(css_prop, value, selector) do
    css_value = Value.to_css(value, css_prop)
    class_name = Hash.atomic_class(css_prop, css_value, selector, nil, nil)

    {ltr_css, rtl_css} =
      ClassCSS.generate_metadata(class_name, css_prop, css_value, selector, nil)

    priority = Priority.calculate(css_prop, selector, nil)

    {"#{css_prop}#{selector}",
     %{
       class: class_name,
       value: css_value,
       pseudo_element: selector,
       ltr: ltr_css,
       rtl: rtl_css,
       priority: priority
     }}
  end

  defp process_dynamic_declarations(props) do
    # For dynamic rules, the CSS value is var(--x-prop)
    # This allows runtime values to be set via inline style
    atomic =
      props
      |> Enum.map(fn prop ->
        css_prop = Value.to_css_property(prop)
        css_var = "--x-#{css_prop}"
        css_value = "var(#{css_var})"
        class_name = Hash.atomic_class(css_prop, css_value, nil, nil, nil)
        {css_prop, %{class: class_name, value: css_value, var: css_var}}
      end)
      |> Map.new()

    class_string =
      atomic
      |> Map.values()
      |> Enum.map_join(" ", & &1.class)

    {atomic, class_string}
  end
end
