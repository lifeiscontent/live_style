defmodule LiveStyle.CSS do
  @moduledoc """
  CSS generation from LiveStyle manifest.

  Generates complete CSS output including:
  - CSS custom properties (variables)
  - @property rules for typed variables
  - @keyframes animations
  - @position-try rules
  - View transition pseudo-element rules
  - Atomic style rules (with RTL support)
  - Theme override rules

  Uses compile-time function generation for optimized priority lookups.
  """

  alias LiveStyle.Manifest
  alias LiveStyle.RTL

  # Vendor-prefixed variants for ::thumb pseudo-element
  # StyleX expands ::thumb to these three selectors for cross-browser compatibility
  @thumb_variants [
    "::-webkit-slider-thumb",
    "::-moz-range-thumb",
    "::-ms-thumb"
  ]

  @doc """
  Expands ::thumb pseudo-element to vendor-prefixed variants.

  StyleX converts `::thumb` to a comma-separated list of vendor-prefixed selectors:
  - `::-webkit-slider-thumb` (Chrome, Safari, Edge)
  - `::-moz-range-thumb` (Firefox)
  - `::-ms-thumb` (IE/old Edge)

  ## Examples

      iex> LiveStyle.CSS.expand_thumb_selector(".x123::thumb")
      ".x123::-webkit-slider-thumb, .x123::-moz-range-thumb, .x123::-ms-thumb"

      iex> LiveStyle.CSS.expand_thumb_selector(".x123:hover")
      ".x123:hover"
  """
  def expand_thumb_selector(selector) do
    if String.contains?(selector, "::thumb") do
      # Replace ::thumb with each vendor prefix and join with commas
      @thumb_variants
      |> Enum.map(fn variant ->
        String.replace(selector, "::thumb", variant)
      end)
      |> Enum.join(", ")
    else
      selector
    end
  end

  @doc """
  Generates complete CSS from the manifest.
  """
  @spec generate(Manifest.t()) :: String.t()
  def generate(manifest) do
    [
      generate_properties(manifest),
      generate_vars(manifest),
      generate_keyframes(manifest),
      generate_position_try(manifest),
      generate_view_transitions(manifest),
      generate_rules(manifest),
      generate_themes(manifest)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc """
  Writes CSS to a file if it has changed.
  """
  @spec write(String.t(), keyword()) :: {:ok, :written | :unchanged} | {:error, term()}
  def write(path, opts \\ []) do
    manifest = LiveStyle.Storage.read()
    css = generate(manifest)

    # Add stats comment if requested
    css =
      if Keyword.get(opts, :stats, true) do
        stats = collect_stats(manifest)
        "/* LiveStyle: #{stats} */\n\n#{css}"
      else
        css
      end

    case File.read(path) do
      {:ok, existing} when existing == css ->
        {:ok, :unchanged}

      _ ->
        dir = Path.dirname(path)

        with :ok <- File.mkdir_p(dir),
             :ok <- File.write(path, css) do
          {:ok, :written}
        end
    end
  end

  @doc """
  Converts a style map to an inline CSS string.
  """
  @spec inline_style(map()) :: String.t()
  def inline_style(style_map) when is_map(style_map) do
    style_map
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)
  end

  defp collect_stats(manifest) do
    vars_count = map_size(manifest.vars)
    keyframes_count = map_size(manifest.keyframes)
    rules_count = map_size(manifest.rules)
    themes_count = map_size(manifest.themes)

    "#{vars_count} vars, #{keyframes_count} keyframes, #{rules_count} rules, #{themes_count} themes"
  end

  # ===========================================================================
  # @property rules for typed variables
  # ===========================================================================

  defp generate_properties(manifest) do
    manifest.vars
    |> Enum.filter(fn {_key, entry} -> entry.type != nil end)
    |> Enum.map(fn {_key, entry} ->
      %{css_name: css_name, type: type_info} = entry
      %{syntax: syntax, initial: initial} = type_info
      inherits = Map.get(type_info, :inherits, true)

      # Extract default value for @property initial-value
      # For conditional values, use the default
      initial_value = extract_initial_value(initial)

      # StyleX format: @property --var { syntax: "<type>"; inherits: true; initial-value: value }
      # Single line, double quotes around syntax, no trailing semicolon
      "@property #{css_name} { syntax: \"#{syntax}\"; inherits: #{inherits}; initial-value: #{initial_value} }"
    end)
    |> Enum.join("\n")
  end

  # Extract the initial value for @property rules
  # For conditional values (maps), use the :default key
  defp extract_initial_value(%{default: default}) when is_binary(default), do: default
  defp extract_initial_value(%{"default" => default}) when is_binary(default), do: default
  defp extract_initial_value(value) when is_binary(value), do: value
  defp extract_initial_value(value) when is_number(value), do: to_string(value)

  defp extract_initial_value(%{} = map) do
    # Try to find :default or "default" key
    case Map.get(map, :default) || Map.get(map, "default") do
      nil -> map |> Map.values() |> List.first() |> to_string()
      val when is_binary(val) -> val
      val -> to_string(val)
    end
  end

  defp extract_initial_value(value), do: to_string(value)

  # ===========================================================================
  # CSS Variables (:root)
  # ===========================================================================

  defp generate_vars(manifest) do
    vars = manifest.vars

    if map_size(vars) == 0 do
      ""
    else
      # Collect all CSS variable rules with their at-rule wrappers
      # Returns a list of {at_rules_list, css_name, value} tuples
      var_rules =
        vars
        |> Enum.flat_map(fn {_key, entry} ->
          %{css_name: css_name, value: value} = entry
          flatten_var_value(css_name, value, [])
        end)

      # Group by at-rules to create CSS blocks
      grouped =
        var_rules
        |> Enum.group_by(fn {at_rules, _name, _val} -> at_rules end)

      # Generate CSS for each group
      # StyleX format: ":root{--var:value;}" or "@media ...{:root{--var:value;}}"
      grouped
      |> Enum.sort_by(fn {at_rules, _} -> length(at_rules) end)
      |> Enum.map(fn {at_rules, vars_list} ->
        declarations =
          vars_list
          |> Enum.sort_by(fn {_, name, _} -> name end)
          |> Enum.map(fn {_, name, value} -> "#{name}:#{value};" end)
          |> Enum.join("")

        # Build the CSS rule with :root selector (no spaces - StyleX format)
        inner = ":root{#{declarations}}"

        # Wrap with at-rules (no spaces - StyleX format)
        # StyleX nests innermost @-rule as outermost wrapper
        at_rules
        |> Enum.reduce(inner, fn at_rule, acc ->
          "#{at_rule}{#{acc}}"
        end)
      end)
      |> Enum.join("\n")
    end
  end

  # Flatten a variable value into a list of {at_rules, css_name, value} tuples
  # Handles nested conditional values like:
  # %{default: "blue", "@media ...": %{default: "lightblue", "@supports ...": "oklab(...)"}}
  defp flatten_var_value(css_name, value, at_rules) when is_map(value) do
    value
    |> Enum.flat_map(fn {key, val} ->
      key_str = to_string(key)

      cond do
        key in [:default, "default"] ->
          # Default value at this level
          if is_binary(val) or is_number(val) do
            [{at_rules, css_name, to_string(val)}]
          else
            # Nested map in default - shouldn't happen but handle gracefully
            flatten_var_value(css_name, val, at_rules)
          end

        match?(<<"@", _rest::binary>>, key_str) ->
          # At-rule condition - add to the at_rules stack
          flatten_var_value(css_name, val, at_rules ++ [key_str])

        true ->
          # Other keys (like pseudo-classes) - treat as at-rule for now
          flatten_var_value(css_name, val, at_rules ++ [key_str])
      end
    end)
  end

  defp flatten_var_value(css_name, value, at_rules) when is_binary(value) do
    [{at_rules, css_name, value}]
  end

  defp flatten_var_value(css_name, value, at_rules) do
    [{at_rules, css_name, to_string(value)}]
  end

  # ===========================================================================
  # @keyframes
  # ===========================================================================

  defp generate_keyframes(manifest) do
    manifest.keyframes
    |> Enum.flat_map(fn {_key, entry} ->
      %{css_name: css_name, frames: frames} = entry

      # Generate LTR and RTL versions of each frame
      {ltr_frames, rtl_frames} = transform_keyframes_for_rtl(frames)

      ltr_css = build_keyframes_css(css_name, ltr_frames)
      rtl_css = build_keyframes_css(css_name, rtl_frames)

      # Only include RTL if it differs from LTR
      if ltr_css == rtl_css do
        [ltr_css]
      else
        [ltr_css, "html[dir=\"rtl\"]{#{rtl_css}}"]
      end
    end)
    |> Enum.join("\n")
  end

  # Transform keyframe declarations through RTL module
  defp transform_keyframes_for_rtl(frames) do
    ltr_frames =
      frames
      |> Enum.map(fn {selector, declarations} ->
        ltr_decls =
          declarations
          |> Enum.map(fn {prop, val} ->
            css_prop = LiveStyle.Value.to_css_property(prop)
            css_val = if is_binary(val), do: val, else: to_string(val)
            {ltr_prop, ltr_val} = LiveStyle.RTL.generate_ltr(css_prop, css_val)
            {ltr_prop, ltr_val}
          end)

        {selector, ltr_decls}
      end)

    rtl_frames =
      frames
      |> Enum.map(fn {selector, declarations} ->
        rtl_decls =
          declarations
          |> Enum.map(fn {prop, val} ->
            css_prop = LiveStyle.Value.to_css_property(prop)
            css_val = if is_binary(val), do: val, else: to_string(val)

            # Try to get RTL version, fall back to LTR if no RTL needed
            case LiveStyle.RTL.generate_rtl(css_prop, css_val) do
              nil ->
                {ltr_prop, ltr_val} = LiveStyle.RTL.generate_ltr(css_prop, css_val)
                {ltr_prop, ltr_val}

              {rtl_prop, rtl_val} ->
                {rtl_prop, rtl_val}
            end
          end)

        {selector, rtl_decls}
      end)

    {ltr_frames, rtl_frames}
  end

  # Build keyframes CSS in minified StyleX format
  # StyleX format: @keyframes name{from{color:red;}to{color:blue;}}
  defp build_keyframes_css(css_name, frames) do
    frame_css =
      frames
      |> Enum.sort_by(fn {selector, _} -> frame_sort_key(selector) end)
      |> Enum.map_join("", fn {selector, declarations} ->
        selector_str = if is_atom(selector), do: to_string(selector), else: selector
        decl_str = format_keyframe_declarations(declarations)
        "#{selector_str}{#{decl_str}}"
      end)

    "@keyframes #{css_name}{#{frame_css}}"
  end

  # Format keyframe declarations in minified format (prop:value;)
  defp format_keyframe_declarations(declarations) do
    declarations
    |> Enum.map_join("", fn {prop, val} ->
      # Unwrap var() from property names (for keyframes that animate CSS variables)
      # e.g., "var(--v08108998)" -> "--v08108998"
      css_prop = prop |> to_string() |> unwrap_var()
      "#{css_prop}:#{val};"
    end)
  end

  defp frame_sort_key(:from), do: {0, "from"}
  defp frame_sort_key(:to), do: {100, "to"}
  defp frame_sort_key("from"), do: {0, "from"}
  defp frame_sort_key("to"), do: {100, "to"}

  defp frame_sort_key(selector) when is_atom(selector) do
    frame_sort_key(to_string(selector))
  end

  defp frame_sort_key(selector) when is_binary(selector) do
    # Extract percentage for sorting: "50%" -> 50
    case Integer.parse(String.replace(selector, "%", "")) do
      {num, _} -> {num, selector}
      :error -> {50, selector}
    end
  end

  # ===========================================================================
  # @position-try
  # ===========================================================================

  defp generate_position_try(manifest) do
    manifest.position_try
    |> Enum.flat_map(fn {_key, entry} ->
      case entry do
        # New format with LTR/RTL variants
        %{ltr: ltr_rule, rtl: nil} ->
          [ltr_rule]

        %{ltr: ltr_rule, rtl: rtl_rule} ->
          # Note: RTL variants for @position-try are rare since logical
          # properties are handled by the browser. If present, we output both.
          [ltr_rule, rtl_rule]

        # Legacy format with css_name and declarations (from css_position_try macro)
        %{css_name: css_name, declarations: declarations} ->
          generate_position_try_from_declarations(css_name, declarations)
      end
    end)
    |> Enum.join("\n")
  end

  # Generate position-try rules from declarations in minified format
  # Note: We keep logical properties as-is (browser handles RTL automatically)
  defp generate_position_try_from_declarations(css_name, declarations) do
    decl_str =
      declarations
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join("", fn {k, v} ->
        css_prop = LiveStyle.Value.to_css_property(k)
        css_value = to_string(v)
        "#{css_prop}:#{css_value};"
      end)

    ["@position-try #{css_name}{#{decl_str}}"]
  end

  # ===========================================================================
  # View Transitions
  # ===========================================================================

  # Map view transition keys (snake_case atoms) to CSS pseudo-elements
  @pseudo_element_map %{
    group: "view-transition-group",
    image_pair: "view-transition-image-pair",
    old: "view-transition-old",
    new: "view-transition-new"
  }

  # String keys map to their snake_case atom equivalents
  @string_to_atom_keys %{
    "group" => :group,
    "image-pair" => :image_pair,
    "old" => :old,
    "new" => :new
  }

  # Generate view transitions in minified StyleX format
  # StyleX format: ::view-transition-old(*.name){animation-duration:.5s;}::view-transition-new(*.name){...}
  defp generate_view_transitions(manifest) do
    manifest.view_transitions
    |> Enum.map(fn {_key, entry} ->
      %{css_name: css_name, styles: styles} = entry

      # All pseudo-elements for one view transition on a single line
      styles
      |> Enum.map_join("", fn {pseudo_key, declarations} ->
        # Normalize string keys to atoms
        normalized_key = Map.get(@string_to_atom_keys, pseudo_key, pseudo_key)
        pseudo_element = Map.get(@pseudo_element_map, normalized_key, to_string(pseudo_key))
        selector = "::#{pseudo_element}(*.#{css_name})"
        decl_str = format_declarations_minified(declarations)
        "#{selector}{#{decl_str}}"
      end)
    end)
    |> Enum.join("\n")
  end

  # Format declarations in minified format (prop:value;)
  defp format_declarations_minified(declarations) do
    declarations
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {k, v} ->
      css_prop = LiveStyle.Value.to_css_property(k)
      css_value = LiveStyle.Value.to_css(v, css_prop)
      "#{css_prop}:#{css_value};"
    end)
  end

  # ===========================================================================
  # Style Rules (Atomic Classes)
  # ===========================================================================

  defp generate_rules(manifest) do
    # Collect all unique atomic classes (both simple and conditional)
    # Format: {class_name, property, value, selector_suffix, pseudo_element, fallback_values, at_rule, priority}
    all_classes =
      manifest.rules
      |> Enum.flat_map(fn {_key, entry} ->
        %{atomic_classes: atomic_classes} = entry

        Enum.flat_map(atomic_classes, fn
          # Skip null entries (StyleX behavior: nil values don't generate CSS)
          {_property, %{null: true}} ->
            []

          # Simple atomic class (may have pseudo_element or fallback_values)
          {property, %{class: class_name, value: value} = data}
          when not is_map_key(data, :classes) ->
            selector_suffix = Map.get(data, :selector_suffix)
            pseudo_element = Map.get(data, :pseudo_element)
            fallback_values = Map.get(data, :fallback_values)
            at_rule = Map.get(data, :at_rule)
            priority = Map.get(data, :priority, 3000)
            # Extract property name without pseudo-element suffix
            actual_property = extract_property_name(property)

            [
              {class_name, actual_property, value, selector_suffix, pseudo_element,
               fallback_values, at_rule, priority}
            ]

          # Conditional atomic class with multiple variants
          {property, %{classes: classes}} ->
            Enum.map(classes, fn {_condition,
                                  %{
                                    class: class_name,
                                    value: value
                                  } = data} ->
              selector_suffix = Map.get(data, :selector_suffix)
              pseudo_element = Map.get(data, :pseudo_element)
              fallback_values = Map.get(data, :fallback_values)
              at_rule = Map.get(data, :at_rule)
              priority = Map.get(data, :priority, 3000)
              actual_property = extract_property_name(property)

              {class_name, actual_property, value, selector_suffix, pseudo_element,
               fallback_values, at_rule, priority}
            end)
        end)
      end)
      |> Enum.uniq_by(fn {class_name, _, _, _, _, _, _, _} -> class_name end)
      |> Enum.sort_by(fn {_class_name, property, _value, _selector_suffix, _pseudo_element,
                          _fallback_values, _at_rule, priority} ->
        # Sort by priority: lower priority number = earlier in stylesheet
        # This follows StyleX's priority system
        {priority, property}
      end)

    use_layers = LiveStyle.Config.use_css_layers?()
    use_priority_layers = LiveStyle.Config.use_priority_layers?()

    if use_layers and use_priority_layers do
      generate_rules_with_priority_layers(all_classes)
    else
      generate_rules_simple(all_classes, use_layers)
    end
  end

  # Generate rules grouped by priority level into separate @layer blocks
  # This matches StyleX's useLayers: true behavior
  defp generate_rules_with_priority_layers(all_classes) do
    # Group classes by priority level (floor(priority / 1000))
    # StyleX uses 1-based indexing for layer names
    grouped =
      all_classes
      |> Enum.group_by(fn {_, _, _, _, _, _, _, priority} ->
        div(priority, 1000)
      end)
      |> Enum.sort_by(fn {level, _} -> level end)

    if Enum.empty?(grouped) do
      ""
    else
      # Generate layer declaration header: @layer priority1, priority2, ...;
      layer_names =
        grouped
        |> Enum.with_index(1)
        |> Enum.map(fn {_, index} -> "priority#{index}" end)
        |> Enum.join(", ")

      header = "@layer #{layer_names};\n"

      # Generate each priority layer
      layer_css =
        grouped
        |> Enum.with_index(1)
        |> Enum.map(fn {{_level, classes}, index} ->
          {ltr_rules, rtl_rules} = generate_rules_for_classes(classes)

          ltr_css = ltr_rules |> Enum.reverse() |> Enum.join("\n")
          rtl_css = rtl_rules |> Enum.reverse() |> Enum.join("\n")

          rules_css =
            case rtl_css do
              "" -> ltr_css
              _ -> ltr_css <> "\n\n/* RTL Overrides */\n" <> rtl_css
            end

          "@layer priority#{index}{\n#{rules_css}\n}"
        end)
        |> Enum.join("\n")

      header <> layer_css <> "\n"
    end
  end

  # Generate rules with simple @layer wrapper or no wrapper
  defp generate_rules_simple(all_classes, use_layers) do
    {ltr_rules, rtl_rules} = generate_rules_for_classes(all_classes)

    # Combine LTR rules (reversed to restore order) with RTL rules
    ltr_css = ltr_rules |> Enum.reverse() |> Enum.join("\n")
    rtl_css = rtl_rules |> Enum.reverse() |> Enum.join("\n")

    rules_css =
      case rtl_css do
        "" -> ltr_css
        _ -> ltr_css <> "\n\n/* RTL Overrides */\n" <> rtl_css
      end

    # Wrap in @layer for cascade control (if enabled)
    if rules_css == "" do
      ""
    else
      if use_layers do
        "@layer live_style {\n#{rules_css}\n}\n"
      else
        rules_css <> "\n"
      end
    end
  end

  # Generate LTR and RTL rules for a list of classes
  defp generate_rules_for_classes(all_classes) do
    use_layers = LiveStyle.Config.use_css_layers?()

    all_classes
    |> Enum.reduce({[], []}, fn {class_name, property, value, selector_suffix, pseudo_element,
                                 fallback_values, at_rule, _priority},
                                {ltr_acc, rtl_acc} ->
      # Generate LTR and optional RTL CSS
      {ltr_prop, ltr_val, rtl_css} = RTL.generate_ltr_rtl(property, value, class_name)

      # Build base selector with optional suffix and pseudo-element
      base_selector =
        cond do
          pseudo_element != nil ->
            ".#{class_name}#{pseudo_element}"

          selector_suffix != nil ->
            ".#{class_name}#{selector_suffix}"

          true ->
            ".#{class_name}"
        end

      # Apply specificity bumping (StyleX behavior)
      # When using @layer, we double the class selector for:
      # - at-rules (@media, @supports, etc.)
      # - conditional pseudo-selectors (:where(), :nth-child, etc.)
      # When not using @layer, we add :not(#\#) pseudo-selectors

      # Determine if we need specificity bumping
      needs_bump = at_rule != nil or selector_suffix != nil

      raw_selector =
        if needs_bump do
          if use_layers do
            # Double the class selector for specificity (StyleX behavior)
            bumped_class = ".#{class_name}.#{class_name}"

            cond do
              pseudo_element != nil -> "#{bumped_class}#{pseudo_element}"
              selector_suffix != nil -> "#{bumped_class}#{selector_suffix}"
              true -> bumped_class
            end
          else
            # Use :not(#\#) for specificity bumping (StyleX default behavior)
            specificity_bump = ":not(#\\#)"

            cond do
              pseudo_element != nil -> ".#{class_name}#{specificity_bump}#{pseudo_element}"
              selector_suffix != nil -> ".#{class_name}#{specificity_bump}#{selector_suffix}"
              true -> ".#{class_name}#{specificity_bump}"
            end
          end
        else
          base_selector
        end

      # Expand ::thumb to vendor-prefixed variants (StyleX behavior)
      selector = expand_thumb_selector(raw_selector)

      # Handle fallback values - generate multiple declarations
      # StyleX uses minified format: .class{prop:value}
      inner_rule =
        case fallback_values do
          nil ->
            "#{selector}{#{ltr_prop}:#{ltr_val}}"

          values when is_list(values) ->
            # StyleX firstThatWorks behavior:
            # - var() values get nested with previous values as fallbacks
            # - Non-var values become separate declarations (for browser fallbacks)
            declarations = process_fallback_values(values, ltr_prop)
            "#{selector}{#{declarations}}"
        end

      # Wrap in at-rule if present
      # StyleX uses minified format: @media ...{.class{prop:value}}
      ltr_rule =
        if at_rule do
          "#{at_rule}{#{inner_rule}}"
        else
          inner_rule
        end

      # Handle RTL with selector suffix
      rtl_acc =
        case rtl_css do
          nil ->
            rtl_acc

          css when selector_suffix != nil ->
            # Rewrite RTL rule to include selector suffix
            rtl_rule = rewrite_rtl_rule_with_suffix(css, selector_suffix)
            [rtl_rule | rtl_acc]

          css when pseudo_element != nil ->
            # Rewrite RTL rule to include pseudo-element
            rtl_rule = rewrite_rtl_rule_with_suffix(css, pseudo_element)
            [rtl_rule | rtl_acc]

          css ->
            [css | rtl_acc]
        end

      {[ltr_rule | ltr_acc], rtl_acc}
    end)
  end

  # Process fallback values according to StyleX firstThatWorks pattern
  # - var() values get nested with previous values as fallbacks
  # - Non-var values become separate declarations (for browser fallbacks)
  # StyleX uses minified format: prop:value;prop:value;
  #
  # Examples:
  # ["sticky", "-webkit-sticky", "fixed"]
  #   => "position:fixed;position:-webkit-sticky;position:sticky"
  #
  # ["500px", "var(--height)", "100dvh"]
  #   => "height:100dvh;height:var(--height,500px)"
  #
  # ["500px", "var(--x)", "var(--y)", "100dvh"]
  #   => "height:100dvh;height:var(--y,var(--x,500px))"
  defp process_fallback_values(values, property) do
    # Check if any values contain var()
    has_vars = Enum.any?(values, &String.contains?(&1, "var("))

    if has_vars do
      # Complex case: need to nest var() values with fallbacks
      process_var_fallbacks(values, property)
    else
      # Simple case: just multiple browser fallback values
      # Generate in reverse order (browsers use last they understand)
      # StyleX minified format: prop:value;prop:value
      values
      |> Enum.reverse()
      |> Enum.map(fn val -> "#{property}:#{val}" end)
      |> Enum.join(";")
    end
  end

  # Process values that contain var() references
  # Var values get nested with prior non-var values as fallbacks
  defp process_var_fallbacks(values, property) do
    # Walk through values, building nested var() chains
    # When we hit a non-var after vars, output the chain and start fresh
    {output, pending_chain} =
      Enum.reduce(values, {[], nil}, fn value, {out, chain} ->
        is_var = String.contains?(value, "var(")

        case {is_var, chain} do
          {true, nil} ->
            # First var(), no fallback yet
            {out, value}

          {true, prev} when is_binary(prev) ->
            # Another var() - nest with previous
            if String.contains?(prev, "var(") do
              # Previous is also a var - nest this one around it
              {out, nest_var_with_fallback(value, prev)}
            else
              # Previous is a plain value - use as fallback
              {out, nest_var_with_fallback(value, prev)}
            end

          {false, nil} ->
            # Non-var, no pending chain - this becomes potential fallback
            {out, value}

          {false, prev} ->
            # Non-var after a chain - output the chain, this becomes new potential fallback
            {[prev | out], value}
        end
      end)

    # Handle any remaining pending chain
    final_output =
      case pending_chain do
        nil -> output
        chain -> [chain | output]
      end

    # Generate declarations in reverse order
    # StyleX minified format: prop:value;prop:value
    final_output
    |> Enum.reverse()
    |> Enum.map(fn val -> "#{property}:#{val}" end)
    |> Enum.join(";")
  end

  # Nest a var() with a fallback value
  # "var(--height)" + "500px" => "var(--height,500px)"
  # StyleX minified format: no space after comma
  defp nest_var_with_fallback(var_value, fallback) do
    # Replace the closing ) with ,fallback)
    String.replace(var_value, ~r/\)$/, ",#{fallback})")
  end

  # Rewrite RTL rule to include selector suffix
  # Input: "html[dir=\"rtl\"] .xabc123 { margin-left: 10px; }"
  # Output: "html[dir=\"rtl\"] .xabc123:where(.x-marker:hover *) { margin-left: 10px; }"
  defp rewrite_rtl_rule_with_suffix(rtl_css, selector_suffix) do
    # Match the class selector in the RTL rule and append the suffix
    Regex.replace(~r/(\.x[a-f0-9]+)(\s*\{)/, rtl_css, "\\1#{selector_suffix}\\2")
  end

  # ===========================================================================
  # Themes
  # ===========================================================================

  defp generate_themes(manifest) do
    manifest.themes
    |> Enum.flat_map(fn {_key, entry} ->
      %{css_name: css_name, overrides: overrides} = entry

      # Collect all rules: default, single-level conditional, and nested conditional
      # Each rule is {conditions_list, name, value} where conditions_list is a list of @-rule strings
      rules = collect_theme_rules(overrides, [])

      # Group rules by their condition path
      grouped =
        rules
        |> Enum.group_by(fn {conditions, _name, _value} -> conditions end)

      # Generate CSS for each condition group
      grouped
      |> Enum.sort_by(fn {conditions, _} -> {length(conditions), conditions} end)
      |> Enum.map(fn {conditions, vars_list} ->
        declarations =
          vars_list
          |> Enum.sort_by(fn {_, name, _} -> name end)
          |> Enum.map(fn {_, name, value} -> "#{name}:#{value};" end)
          |> Enum.join("")

        selector = ".#{css_name},.#{css_name}:root"

        case conditions do
          [] ->
            # Default rule
            "#{selector}{#{declarations}}"

          _ ->
            # Wrap in nested @-rules (reversed so innermost is last)
            inner = "#{selector}{#{declarations}}"

            Enum.reduce(Enum.reverse(conditions), inner, fn condition, acc ->
              "#{condition}{#{acc}}"
            end)
        end
      end)
    end)
    |> Enum.join("\n")
  end

  # Recursively collect theme rules, tracking the condition path
  defp collect_theme_rules(overrides, conditions_path) do
    Enum.flat_map(overrides, fn {name, value} ->
      collect_theme_value(name, value, conditions_path)
    end)
  end

  defp collect_theme_value(name, value, conditions_path) when is_map(value) do
    # Handle map values with :default and @-rule keys
    Enum.flat_map(value, fn
      {key, inner_value} when key in [:default, "default"] ->
        # Default value at this level
        if is_map(inner_value) do
          # Nested default (unusual but possible)
          collect_theme_value(name, inner_value, conditions_path)
        else
          [{conditions_path, name, to_string(inner_value)}]
        end

      {condition, inner_value} ->
        # Conditional value - add to condition path
        condition_str = to_string(condition)

        if is_map(inner_value) do
          # Nested conditionals
          collect_theme_value(name, inner_value, conditions_path ++ [condition_str])
        else
          [{conditions_path ++ [condition_str], name, to_string(inner_value)}]
        end
    end)
  end

  defp collect_theme_value(name, value, conditions_path) when is_binary(value) do
    [{conditions_path, name, value}]
  end

  defp collect_theme_value(name, value, conditions_path) do
    [{conditions_path, name, to_string(value)}]
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  # Unwrap var(--name) to just --name for use as property names in keyframes
  defp unwrap_var("var(" <> rest) do
    String.trim_trailing(rest, ")")
  end

  defp unwrap_var(property), do: property

  # Extract property name, removing pseudo-element suffix if present
  # "color::placeholder" => "color"
  defp extract_property_name(property) do
    property
    |> to_string()
    |> String.split("::")
    |> List.first()
  end
end
