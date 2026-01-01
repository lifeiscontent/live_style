defmodule LiveStyle.Compiler.BeforeCompile do
  @moduledoc false
  # Compile-time helpers for __before_compile__

  alias LiveStyle.Manifest

  @doc """
  Builds class string and property class maps for static classes.

  ## Parameters

    * `static_classes` - List of `{name, declaration}` tuples
    * `module` - The module being compiled
    * `manifest` - The manifest to look up classes from (injected for DIP)

  ## Returns

  A tuple of `{class_strings_map, property_classes_map}`.
  """
  @spec build_static_class_maps(list(), module(), Manifest.t()) :: {map(), map()}
  def build_static_class_maps(static_classes, module, manifest) do
    Enum.reduce(static_classes, {%{}, %{}}, fn {name, _decl}, {cs_acc, pc_acc} ->
      build_static_class_map(name, module, manifest, cs_acc, pc_acc)
    end)
  end

  defp build_static_class_map(name, module, manifest, cs_acc, pc_acc) do
    key = Manifest.simple_key(module, name)

    case Manifest.get_class(manifest, key) do
      %{class_string: cs, atomic_classes: atomic_classes} ->
        prop_classes = build_prop_classes(atomic_classes)
        {Map.put(cs_acc, name, cs), Map.put(pc_acc, name, prop_classes)}

      nil ->
        {Map.put(cs_acc, name, ""), Map.put(pc_acc, name, %{})}
    end
  end

  defp build_prop_classes(atomic_classes) do
    atomic_classes
    |> Enum.flat_map(&build_prop_class_entry/1)
    |> Map.new()
  end

  defp build_prop_class_entry({prop, %{class: nil, unset: true}}) do
    [{prop, :__unset__}]
  end

  defp build_prop_class_entry({prop, %{class: class}}) when class != nil do
    [{prop, class}]
  end

  defp build_prop_class_entry({prop, %{classes: classes}}) do
    Enum.flat_map(classes, fn entry -> build_conditional_entry(prop, entry) end)
  end

  defp build_prop_class_entry(_), do: []

  defp build_conditional_entry(prop, {condition, %{class: nil}}) do
    [{"#{prop}::#{condition}", :__unset__}]
  end

  defp build_conditional_entry(prop, {condition, %{class: class}}) when class != nil do
    [{"#{prop}::#{condition}", class}]
  end

  defp build_conditional_entry(_prop, _), do: []

  @doc false
  def build_dynamic_fns(dynamic_rules, module) do
    Enum.map(dynamic_rules, fn {name, {:__dynamic__, all_props, param_names, has_computed}} ->
      fn_name = :"__dynamic_#{name}__"

      quote do
        @doc false
        def unquote(fn_name)(values) do
          LiveStyle.Runtime.process_dynamic_rule(
            unquote(Macro.escape(all_props)),
            unquote(param_names),
            values,
            unquote(module),
            unquote(name),
            unquote(has_computed)
          )
        end
      end
    end)
  end
end
