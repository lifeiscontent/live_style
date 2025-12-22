defmodule LiveStyle.CSS.AtomicRules.Renderer do
  @moduledoc false

  alias LiveStyle.CSS.AtomicClass
  alias LiveStyle.CSS.Selector
  alias LiveStyle.RTL

  @type class_tuple :: LiveStyle.CSS.AtomicRules.Collector.class_tuple()

  @spec render([class_tuple()]) :: String.t()
  def render(classes) do
    if LiveStyle.Config.use_css_layers?() do
      render_with_layers(classes)
    else
      css = render_simple(classes)
      if css == "", do: "", else: css <> "\n"
    end
  end

  defp render_with_layers(classes) do
    grouped =
      classes
      |> Enum.group_by(fn {_, _, _, _, _, _, _, priority} -> div(priority, 1000) end)
      |> Enum.sort_by(fn {level, _} -> level end)

    if Enum.empty?(grouped) do
      ""
    else
      header = layer_header(grouped)
      layer_css = priority_layers(grouped)
      header <> layer_css <> "\n"
    end
  end

  defp layer_header(grouped) do
    layer_names =
      grouped
      |> Enum.with_index(1)
      |> Enum.map_join(", ", fn {_, index} -> "priority#{index}" end)

    "@layer #{layer_names};\n"
  end

  defp priority_layers(grouped) do
    grouped
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{_level, classes}, index} ->
      rules_css = render_ltr_rtl_css(classes)
      "@layer priority#{index}{\n#{rules_css}\n}"
    end)
  end

  defp render_simple(classes), do: render_ltr_rtl_css(classes)

  defp render_ltr_rtl_css(classes) do
    {ltr_rules, rtl_rules} = render_rules_for_classes(classes)
    ltr_css = ltr_rules |> Enum.reverse() |> Enum.join("\n")
    rtl_css = rtl_rules |> Enum.reverse() |> Enum.join("\n")

    case rtl_css do
      "" -> ltr_css
      _ -> ltr_css <> "\n\n/* RTL Overrides */\n" <> rtl_css
    end
  end

  defp render_rules_for_classes(all_classes) do
    Enum.reduce(all_classes, {[], []}, fn class_tuple, {ltr_acc, rtl_acc} ->
      {ltr_rule, rtl_rule} = render_rule_for_class(class_tuple)
      rtl_acc = if rtl_rule, do: [rtl_rule | rtl_acc], else: rtl_acc
      {[ltr_rule | ltr_acc], rtl_acc}
    end)
  end

  defp render_rule_for_class(
         {class_name, property, value, selector_suffix, pseudo_element, fallback_values, at_rule,
          _priority}
       ) do
    {ltr_prop, ltr_val} = RTL.generate_ltr(property, value)
    rtl_pair = RTL.generate_rtl(property, value)

    selector =
      Selector.build_atomic_rule_selector(class_name, selector_suffix, pseudo_element, at_rule)

    inner_rule = build_inner_rule(selector, ltr_prop, ltr_val, fallback_values)
    ltr_rule = AtomicClass.wrap_in_at_rules(at_rule, inner_rule)

    rtl_rule =
      case rtl_pair do
        nil ->
          nil

        {rtl_prop, rtl_val} ->
          rtl_decl = LiveStyle.Config.apply_prefix_css(rtl_prop, rtl_val)
          rtl_selector = Selector.prefix_rtl(selector)
          AtomicClass.wrap_in_at_rules(at_rule, "#{rtl_selector}{#{rtl_decl}}")
      end

    {ltr_rule, rtl_rule}
  end

  defp build_inner_rule(selector, prop, val, nil) do
    declarations = LiveStyle.Config.apply_prefix_css(prop, val)
    "#{selector}{#{declarations}}"
  end

  defp build_inner_rule(selector, prop, _val, values) when is_list(values) do
    declarations = Enum.map_join(values, ";", &LiveStyle.Config.apply_prefix_css(prop, &1))
    "#{selector}{#{declarations}}"
  end
end
