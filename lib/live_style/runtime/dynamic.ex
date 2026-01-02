defmodule LiveStyle.Runtime.Dynamic do
  @moduledoc """
  Runtime support for dynamic CSS classes.

  Dynamic classes have their property_classes embedded at compile time (like StyleX),
  and only the CSS variable values are computed at runtime.
  """

  alias LiveStyle.Config
  alias LiveStyle.CSSValue

  @doc """
  Computes the CSS variable list for a dynamic class.

  Property classes are stored in `@__property_classes__` at compile time,
  so we only need to compute the CSS variable values at runtime.

  Returns a list of `{css_var_name, value}` tuples for inline styles.
  """
  @spec compute_var_list(list(), term(), module(), atom(), boolean()) :: list()
  def compute_var_list(all_props, values, module, name, has_computed) do
    values_list = if is_list(values), do: values, else: [values]
    prefix = Config.class_name_prefix()

    if has_computed do
      compute_fn_name = :"__compute_#{name}__"
      declarations = apply(module, compute_fn_name, [values_list])

      Enum.map(declarations, fn {prop, value} ->
        {"--#{prefix}-#{CSSValue.to_css_property(prop)}", format_css_value(value)}
      end)
    else
      all_props
      |> Enum.zip(values_list)
      |> Enum.map(fn {prop, value} ->
        {"--#{prefix}-#{CSSValue.to_css_property(prop)}", format_css_value(value)}
      end)
    end
  end

  defp format_css_value(value) when is_number(value), do: "#{value}"
  defp format_css_value(value) when is_binary(value), do: value
  defp format_css_value(value), do: to_string(value)
end
