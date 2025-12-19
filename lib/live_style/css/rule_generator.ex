defmodule LiveStyle.CSS.RuleGenerator do
  @moduledoc """
  Generates atomic CSS rules from the manifest's class entries.

  This module handles the generation of the main CSS rules for atomic classes,
  including:
  - LTR and RTL rule generation
  - CSS layer wrapping (optional)
  - Priority-based layer grouping (optional)
  - Selector building with specificity bumping
  - Fallback value processing
  - Selector prefixing (e.g., `::thumb`, `::placeholder`)

  ## Configuration

  Behavior is controlled by `LiveStyle.Config`:
  - `use_css_layers` - Wrap rules in `@layer live_style` (default: true)
  - `use_priority_layers` - Group rules by priority in separate layers (default: false)
  """

  alias LiveStyle.RTL
  alias LiveStyle.Selector.Prefixer, as: SelectorPrefixer

  # Compiled regex patterns
  @rtl_class_selector_regex ~r/(\.x[a-f0-9]+)(\s*\{)/
  @var_closing_paren_regex ~r/\)$/

  @doc """
  Generates all CSS rules from the manifest.

  Returns a string containing all atomic CSS rules, wrapped in layers if configured.
  """
  @spec generate(LiveStyle.Manifest.t()) :: String.t()
  def generate(manifest) do
    all_classes = collect_and_sort_classes(manifest)

    use_layers = LiveStyle.Config.use_css_layers?()
    use_priority_layers = LiveStyle.Config.use_priority_layers?()

    if use_layers and use_priority_layers do
      generate_with_priority_layers(all_classes)
    else
      generate_simple(all_classes, use_layers)
    end
  end

  # Collect all unique atomic classes and sort by priority
  defp collect_and_sort_classes(manifest) do
    manifest.classes
    |> Enum.flat_map(fn {_key, entry} ->
      Enum.flat_map(entry.atomic_classes, &extract_class_tuples/1)
    end)
    |> Enum.uniq_by(fn {class_name, _, _, _, _, _, _, _} -> class_name end)
    |> Enum.sort_by(fn {_class_name, property, _value, _selector_suffix, _pseudo_element,
                        _fallback_values, _at_rule, priority} ->
      {priority, property}
    end)
  end

  # Generate rules grouped by priority level into separate @layer blocks
  defp generate_with_priority_layers(all_classes) do
    grouped =
      all_classes
      |> Enum.group_by(fn {_, _, _, _, _, _, _, priority} -> div(priority, 1000) end)
      |> Enum.sort_by(fn {level, _} -> level end)

    if Enum.empty?(grouped) do
      ""
    else
      header = generate_layer_header(grouped)
      layer_css = generate_priority_layers(grouped)
      header <> layer_css <> "\n"
    end
  end

  defp generate_layer_header(grouped) do
    layer_names =
      grouped
      |> Enum.with_index(1)
      |> Enum.map_join(", ", fn {_, index} -> "priority#{index}" end)

    "@layer #{layer_names};\n"
  end

  defp generate_priority_layers(grouped) do
    grouped
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{_level, classes}, index} ->
      rules_css = generate_ltr_rtl_css(classes)
      "@layer priority#{index}{\n#{rules_css}\n}"
    end)
  end

  # Generate rules with simple @layer wrapper or no wrapper
  defp generate_simple(all_classes, use_layers) do
    all_classes |> generate_ltr_rtl_css() |> wrap_rules(use_layers)
  end

  defp wrap_rules("", _use_layers), do: ""
  defp wrap_rules(rules_css, true), do: "@layer live_style {\n#{rules_css}\n}\n"
  defp wrap_rules(rules_css, false), do: rules_css <> "\n"

  defp generate_ltr_rtl_css(classes) do
    {ltr_rules, rtl_rules} = generate_rules_for_classes(classes)
    ltr_css = ltr_rules |> Enum.reverse() |> Enum.join("\n")
    rtl_css = rtl_rules |> Enum.reverse() |> Enum.join("\n")
    combine_ltr_rtl_css(ltr_css, rtl_css)
  end

  defp combine_ltr_rtl_css(ltr_css, ""), do: ltr_css

  defp combine_ltr_rtl_css(ltr_css, rtl_css),
    do: ltr_css <> "\n\n/* RTL Overrides */\n" <> rtl_css

  # Generate LTR and RTL rules for a list of classes
  defp generate_rules_for_classes(all_classes) do
    Enum.reduce(all_classes, {[], []}, fn class_tuple, {ltr_acc, rtl_acc} ->
      {ltr_rule, rtl_rule} = generate_rule_for_class(class_tuple)
      rtl_acc = if rtl_rule, do: [rtl_rule | rtl_acc], else: rtl_acc
      {[ltr_rule | ltr_acc], rtl_acc}
    end)
  end

  defp generate_rule_for_class(
         {class_name, property, value, selector_suffix, pseudo_element, fallback_values, at_rule,
          _priority}
       ) do
    {ltr_prop, ltr_val, rtl_css} = RTL.generate_ltr_rtl(property, value, class_name)
    selector = build_css_selector(class_name, selector_suffix, pseudo_element, at_rule)
    inner_rule = build_inner_rule(selector, ltr_prop, ltr_val, fallback_values)
    ltr_rule = wrap_at_rule(inner_rule, at_rule)
    rtl_rule = build_rtl_rule(rtl_css, selector_suffix, pseudo_element)

    {ltr_rule, rtl_rule}
  end

  # Extract class tuples from atomic_classes entries
  defp extract_class_tuples({_property, %{null: true}}), do: []

  defp extract_class_tuples({property, %{class: class_name, value: value} = data})
       when not is_map_key(data, :classes) do
    [build_class_tuple(property, class_name, value, data)]
  end

  defp extract_class_tuples({property, %{classes: classes}}) do
    Enum.map(classes, fn {_condition, %{class: class_name, value: value} = data} ->
      build_class_tuple(property, class_name, value, data)
    end)
  end

  defp build_class_tuple(property, class_name, value, data) do
    {
      class_name,
      extract_property_name(property),
      value,
      Map.get(data, :selector_suffix),
      Map.get(data, :pseudo_element),
      Map.get(data, :fallback_values),
      Map.get(data, :at_rule),
      Map.get(data, :priority, 3000)
    }
  end

  # Extract property name, removing pseudo-element suffix if present
  defp extract_property_name(property) do
    property
    |> to_string()
    |> String.split("::")
    |> List.first()
  end

  # Selector building
  defp build_css_selector(class_name, selector_suffix, pseudo_element, at_rule) do
    use_layers = LiveStyle.Config.use_css_layers?()
    needs_bump = at_rule != nil or selector_suffix != nil
    suffix = pseudo_element || selector_suffix

    raw_selector =
      if needs_bump do
        build_bumped_selector(class_name, suffix, use_layers)
      else
        build_base_selector(class_name, suffix)
      end

    SelectorPrefixer.prefix(raw_selector)
  end

  defp build_base_selector(class_name, nil), do: ".#{class_name}"
  defp build_base_selector(class_name, suffix), do: ".#{class_name}#{suffix}"

  defp build_bumped_selector(class_name, suffix, true = _use_layers) do
    bumped = ".#{class_name}.#{class_name}"
    if suffix, do: "#{bumped}#{suffix}", else: bumped
  end

  defp build_bumped_selector(class_name, suffix, false = _use_layers) do
    bump = ":not(#\\#)"
    if suffix, do: ".#{class_name}#{bump}#{suffix}", else: ".#{class_name}#{bump}"
  end

  # Inner rule building
  defp build_inner_rule(selector, prop, val, nil) do
    declarations = LiveStyle.Config.apply_prefixer(prop, val)
    "#{selector}{#{declarations}}"
  end

  defp build_inner_rule(selector, prop, _val, values) when is_list(values) do
    declarations = process_fallback_values(values, prop)
    "#{selector}{#{declarations}}"
  end

  defp wrap_at_rule(rule, nil), do: rule
  defp wrap_at_rule(rule, at_rule), do: "#{at_rule}{#{rule}}"

  # RTL rule building
  defp build_rtl_rule(nil, _suffix, _pseudo), do: nil

  defp build_rtl_rule(css, suffix, _pseudo) when suffix != nil,
    do: rewrite_rtl_rule_with_suffix(css, suffix)

  defp build_rtl_rule(css, _suffix, pseudo) when pseudo != nil,
    do: rewrite_rtl_rule_with_suffix(css, pseudo)

  defp build_rtl_rule(css, _suffix, _pseudo), do: css

  defp rewrite_rtl_rule_with_suffix(rtl_css, selector_suffix) do
    Regex.replace(@rtl_class_selector_regex, rtl_css, "\\1#{selector_suffix}\\2")
  end

  # Fallback value processing
  defp process_fallback_values(values, property) do
    has_vars = Enum.any?(values, &String.contains?(&1, "var("))

    if has_vars do
      process_var_fallbacks(values, property)
    else
      values
      |> Enum.reverse()
      |> Enum.map_join(";", &LiveStyle.Config.apply_prefixer(property, &1))
    end
  end

  defp process_var_fallbacks(values, property) do
    {output, pending_chain} =
      Enum.reduce(values, {[], nil}, fn value, acc ->
        process_var_fallback_step(value, acc)
      end)

    final_output = finalize_var_chain(output, pending_chain)

    final_output
    |> Enum.reverse()
    |> Enum.map_join(";", &LiveStyle.Config.apply_prefixer(property, &1))
  end

  defp process_var_fallback_step(value, {out, nil}), do: {out, value}

  defp process_var_fallback_step(value, {out, prev}) do
    if String.contains?(value, "var(") do
      {out, nest_var_with_fallback(value, prev)}
    else
      {[prev | out], value}
    end
  end

  defp finalize_var_chain(output, nil), do: output
  defp finalize_var_chain(output, chain), do: [chain | output]

  defp nest_var_with_fallback(var_value, fallback) do
    String.replace(var_value, @var_closing_paren_regex, ",#{fallback})")
  end
end
