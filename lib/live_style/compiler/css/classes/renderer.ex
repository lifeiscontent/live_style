defmodule LiveStyle.Compiler.CSS.Classes.Renderer do
  @moduledoc false
  # Renders pre-built CSS rules from Collector.
  # With StyleX model, CSS is pre-built at compile time - just concatenate.

  @type class_tuple :: LiveStyle.Compiler.CSS.Classes.Collector.class_tuple()

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
      |> Enum.group_by(fn {_, priority, _, _} -> div(priority, 1000) end)
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

  # Concatenate pre-built LTR and RTL CSS rules
  defp render_ltr_rtl_css(classes) do
    {ltr_rules, rtl_rules} =
      Enum.reduce(classes, {[], []}, fn {_class, _priority, ltr, rtl}, {ltr_acc, rtl_acc} ->
        rtl_acc = if rtl, do: [rtl | rtl_acc], else: rtl_acc
        {[ltr | ltr_acc], rtl_acc}
      end)

    ltr_css = ltr_rules |> Enum.reverse() |> Enum.join("\n")
    rtl_css = rtl_rules |> Enum.reverse() |> Enum.join("\n")

    case rtl_css do
      "" -> ltr_css
      _ -> ltr_css <> "\n\n/* RTL Overrides */\n" <> rtl_css
    end
  end
end
