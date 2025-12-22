defmodule LiveStyle.Runtime.Dynamic do
  @moduledoc false

  alias LiveStyle.Config
  alias LiveStyle.Manifest
  alias LiveStyle.Value

  @spec process_dynamic_rule(list(), list(), term(), module(), atom(), boolean()) ::
          {String.t(), map()}
  def process_dynamic_rule(all_props, _param_names, values, module, name, has_computed) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    class_string =
      case Manifest.get_class(manifest, key) do
        %{class_string: cs} -> cs
        nil -> ""
      end

    values_list = if is_list(values), do: values, else: [values]
    prefix = Config.class_name_prefix()

    var_map =
      if has_computed do
        compute_fn_name = :"__compute_#{name}__"
        declarations = apply(module, compute_fn_name, [values_list])

        Map.new(declarations, fn {prop, value} ->
          {"--#{prefix}-#{Value.to_css_property(prop)}", format_css_value(value)}
        end)
      else
        all_props
        |> Enum.zip(values_list)
        |> Map.new(fn {prop, value} ->
          {"--#{prefix}-#{Value.to_css_property(prop)}", format_css_value(value)}
        end)
      end

    {class_string, var_map}
  end

  defp format_css_value(value) when is_number(value), do: "#{value}"
  defp format_css_value(value) when is_binary(value), do: value
  defp format_css_value(value), do: to_string(value)
end
