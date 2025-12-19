defmodule LiveStyle.Rule do
  @moduledoc """
  Style rule definition and processing for LiveStyle.

  This module handles:
  - Defining static and dynamic style rules
  - Processing declarations into atomic CSS classes
  - Handling conditional values (pseudo-classes, media queries)
  - Processing pseudo-element declarations

  ## Example

      # Static rule
      LiveStyle.Rule.define(MyModule, :button, %{display: "flex", padding: "8px"})

      # Dynamic rule
      LiveStyle.Rule.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])

      # Lookup
      LiveStyle.Rule.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", ...}
  """

  alias LiveStyle.{Hash, Include, Manifest, Priority, Value}
  alias LiveStyle.MediaQuery.Transform, as: MediaQueryTransform
  alias LiveStyle.Rule.CSS, as: RuleCSS
  alias LiveStyle.Shorthand.Strategy, as: ShorthandStrategy

  @doc """
  Defines a static style rule.

  ## Parameters

    * `module` - The module defining the rule
    * `name` - The rule name (atom)
    * `declarations` - Map of CSS property declarations

  ## Example

      LiveStyle.Rule.define(MyModule, :button, %{display: "flex"})
  """
  @spec define(module(), atom(), map()) :: :ok
  def define(module, name, declarations) do
    key = Manifest.simple_key(module, name)

    # Check if this rule already exists in the manifest (from pre-compilation)
    # If so, skip the write to avoid race conditions during parallel test loading
    manifest = LiveStyle.Storage.read()

    if Manifest.get_rule(manifest, key) do
      :ok
    else
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

      LiveStyle.Storage.update(fn manifest ->
        Manifest.put_rule(manifest, key, entry)
      end)

      :ok
    end
  end

  @doc """
  Defines a dynamic style rule.

  Dynamic rules use CSS variables that are set at runtime via inline styles.

  ## Parameters

    * `module` - The module defining the rule
    * `name` - The rule name (atom)
    * `all_props` - List of all CSS properties in the rule
    * `param_names` - List of parameter names for the dynamic function

  ## Example

      LiveStyle.Rule.define_dynamic(MyModule, :opacity, [:opacity], [:opacity])
  """
  @spec define_dynamic(module(), atom(), [atom()], [atom()]) :: :ok
  def define_dynamic(module, name, all_props, param_names) do
    key = Manifest.simple_key(module, name)

    # Check if this rule already exists in the manifest (from pre-compilation)
    manifest = LiveStyle.Storage.read()

    if Manifest.get_rule(manifest, key) do
      :ok
    else
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

      LiveStyle.Storage.update(fn manifest ->
        Manifest.put_rule(manifest, key, entry)
      end)

      :ok
    end
  end

  @doc """
  Looks up a rule by module and name.

  Returns the rule entry or raises if not found.

  ## Examples

      LiveStyle.Rule.lookup!(MyModule, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}
  """
  @spec lookup!(module(), atom()) :: map()
  def lookup!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_rule(manifest, key) do
      nil ->
        raise ArgumentError, """
        Unknown rule: #{inspect(module)}.#{name}

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

  defp conditional_value?(value) when is_map(value) do
    # A map is conditional if:
    # - It has :default key OR
    # - All keys are selector-like (start with : or @)
    # But NOT if it contains CSS property keys (pseudo-element declarations)
    has_default = Map.has_key?(value, :default) or Map.has_key?(value, "default")
    has_css_props = Enum.any?(Map.keys(value), &css_property_key?/1)
    all_selector_keys = Enum.all?(Map.keys(value), &selector_key?/1)

    (has_default or all_selector_keys) and not has_css_props
  end

  defp conditional_value?(value) when is_list(value) do
    # A list of tuples is conditional if:
    # - It has a :default or "default" key OR
    # - All keys are selector-like (start with : or @)
    has_default =
      Enum.any?(value, fn
        {:default, _} -> true
        {"default", _} -> true
        _ -> false
      end)

    all_selector_keys =
      Enum.all?(value, fn
        {key, _} -> selector_key?(key)
        _ -> false
      end)

    has_default or all_selector_keys
  end

  # Support tuple syntax: {":hover", "value"} as shorthand for %{":hover" => "value"}
  defp conditional_value?({key, _value}) when is_binary(key) do
    selector_key?(key)
  end

  defp conditional_value?({key, _value}) when is_atom(key) do
    selector_key?(key)
  end

  defp conditional_value?(_), do: false

  # Check if a key looks like a CSS selector (pseudo-class, pseudo-element, at-rule)
  defp selector_key?(key) when is_atom(key) do
    selector_key?(Atom.to_string(key))
  end

  defp selector_key?(<<":", _rest::binary>>), do: true
  defp selector_key?(<<"@", _rest::binary>>), do: true
  defp selector_key?(_), do: false

  defp css_property_key?(key) when is_atom(key) do
    key_str = Atom.to_string(key)
    # CSS properties use snake_case or have common property names
    String.contains?(key_str, "_") or
      key in [:content, :display, :color, :opacity, :position, :width, :height]
  end

  defp css_property_key?(_), do: false

  defp process_simple_declarations(declarations) do
    # Expand shorthand properties based on style resolution mode
    expanded =
      declarations
      |> Enum.flat_map(fn {prop, value} ->
        ShorthandStrategy.expand_declaration(prop, value)
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
              RuleCSS.generate_metadata(class_name, css_prop, css_value, nil, nil)

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
      ShorthandStrategy.expand_shorthand_conditions(prop, css_prop, value_map)
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
    {ltr_css, rtl_css} = RuleCSS.generate_metadata(class_name, css_prop, css_value_str, nil, nil)
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
      RuleCSS.generate_metadata(class_name, css_prop, css_value_str, selector_suffix, at_rule)

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

  # Recursively flatten nested conditional values into {selector, value} tuples
  # Example: %{:default => "black", ":hover" => %{:default => "red", ":focus" => "blue"}}
  # Flattens to: [{nil, "black"}, {":hover", "red"}, {":hover:focus", "blue"}]
  defp flatten_conditional_value(value_map, parent_selector) when is_map(value_map) do
    Enum.flat_map(value_map, fn {condition, value} ->
      current_selector = combine_selectors(parent_selector, condition)

      cond do
        is_map(value) and conditional_value?(value) ->
          # Nested conditional map - recurse
          flatten_conditional_value(value, current_selector)

        is_list(value) and conditional_value?(value) ->
          # Nested conditional keyword list - convert to map and recurse
          flatten_conditional_value(Map.new(value), current_selector)

        true ->
          # Leaf value
          [{current_selector, value}]
      end
    end)
  end

  # Handle lists (keyword lists or tuple lists) by converting to map
  defp flatten_conditional_value(value_list, parent_selector) when is_list(value_list) do
    if conditional_value?(value_list) do
      # Convert tuple list to map and recurse
      flatten_conditional_value(Map.new(value_list), parent_selector)
    else
      [{parent_selector, value_list}]
    end
  end

  # Handle tuple syntax: {":hover", "value"} as shorthand for single condition
  defp flatten_conditional_value({selector, value}, parent_selector)
       when is_binary(selector) or is_atom(selector) do
    selector_str = to_string(selector)

    if selector_key?(selector_str) do
      current_selector = combine_selectors(parent_selector, selector_str)

      # Check if the value itself is a nested conditional
      if conditional_value?(value) do
        # Recurse for nested conditionals like {":hover", {":active", "red"}}
        flatten_conditional_value(value, current_selector)
      else
        [{current_selector, value}]
      end
    else
      [{parent_selector, {selector, value}}]
    end
  end

  defp flatten_conditional_value(value, parent_selector) do
    [{parent_selector, value}]
  end

  # Combine parent and child selectors
  defp combine_selectors(nil, key) when key in [:default, "default"], do: nil
  defp combine_selectors(parent, key) when key in [:default, "default"], do: parent

  defp combine_selectors(nil, condition) when is_atom(condition) do
    to_string(condition)
  end

  defp combine_selectors(nil, condition) when is_binary(condition), do: condition

  defp combine_selectors(parent, condition) when is_atom(condition) do
    parent <> to_string(condition)
  end

  defp combine_selectors(parent, condition) when is_binary(condition) do
    parent <> condition
  end

  # Parse a combined selector that may contain both an at-rule and a pseudo-class
  # Examples:
  # - ":hover" -> {":hover", nil}
  # - "@media (x)" -> {nil, "@media (x)"}
  # - "@media (x):hover" -> {":hover", "@media (x)"}
  # - "@supports (x):focus:active" -> {":focus:active", "@supports (x)"}
  defp parse_combined_selector(<<"@", _rest::binary>> = selector) do
    # Find where the pseudo-class starts (first : not inside parentheses)
    case find_pseudo_in_at_rule(selector) do
      nil ->
        # No pseudo-class, just at-rule
        {nil, selector}

      {at_rule, pseudo} ->
        {pseudo, at_rule}
    end
  end

  defp parse_combined_selector(selector) do
    # Just a pseudo-class/selector suffix
    {selector, nil}
  end

  # Find where the pseudo-class starts in an at-rule selector
  # We need to skip over ALL parens to handle nested at-rules like:
  # @media (min-width: 800px)@supports (color: oklch(0 0 0)):hover
  defp find_pseudo_in_at_rule(selector) do
    # Find the LAST closing paren - all at-rules must be before the pseudo-class
    find_last_paren_and_pseudo(selector, byte_size(selector) - 1)
  end

  defp find_last_paren_and_pseudo(_selector, pos) when pos < 0, do: nil

  defp find_last_paren_and_pseudo(selector, pos) do
    char = :binary.part(selector, pos, 1)

    if char == ")" do
      check_after_paren(selector, pos)
    else
      # Not a paren, keep looking backward
      find_last_paren_and_pseudo(selector, pos - 1)
    end
  end

  defp check_after_paren(selector, pos) do
    after_paren = binary_part(selector, pos + 1, byte_size(selector) - pos - 1)

    case after_paren do
      <<":", _::binary>> ->
        at_rule = binary_part(selector, 0, pos + 1)
        {at_rule, after_paren}

      <<"@", _::binary>> ->
        # Another at-rule follows, keep looking backward
        find_last_paren_and_pseudo(selector, pos - 1)

      "" ->
        # End of string, no pseudo-class
        nil

      _ ->
        # Something else, keep looking backward
        find_last_paren_and_pseudo(selector, pos - 1)
    end
  end

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
    {ltr_css, rtl_css} = RuleCSS.generate_metadata(class_name, css_prop, css_value, selector, nil)
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
