defmodule LiveStyle.Compiler.BeforeCompile do
  @moduledoc false
  # Compile-time helpers for __before_compile__

  alias LiveStyle.Manifest

  @doc """
  Builds class string and property class keyword lists for classes.

  ## Parameters

    * `classes` - List of `{name, declaration}` tuples (static) or `{name, {:__dynamic__, ...}}` (dynamic)
    * `module` - The module being compiled
    * `manifest` - The manifest to look up classes from (injected for DIP)

  ## Returns

  A tuple of `{class_strings_list, property_classes_list}`.
  """
  @spec build_class_maps(list(), module(), Manifest.t()) :: {keyword(), keyword()}
  def build_class_maps(classes, module, manifest) do
    Enum.reduce(classes, {[], []}, fn class_entry, {cs_acc, pc_acc} ->
      name = elem(class_entry, 0)
      build_class_map(name, module, manifest, cs_acc, pc_acc)
    end)
  end

  defp build_class_map(name, module, manifest, cs_acc, pc_acc) do
    key = Manifest.key(module, name)

    case Manifest.get_class(manifest, key) do
      entry when is_list(entry) ->
        cs = Keyword.fetch!(entry, :class_string)
        atomic_classes = Keyword.fetch!(entry, :atomic_classes)
        prop_classes = build_prop_classes(atomic_classes)
        {[{name, cs} | cs_acc], [{name, prop_classes} | pc_acc]}

      nil ->
        {[{name, ""} | cs_acc], [{name, []} | pc_acc]}
    end
  end

  defp build_prop_classes(atomic_classes) do
    Enum.flat_map(atomic_classes, &build_prop_class_entry/1)
  end

  defp build_prop_class_entry({prop, entry}) when is_list(entry) do
    cond do
      Keyword.get(entry, :unset) == true and Keyword.get(entry, :class) == nil ->
        [{prop, :__unset__}]

      Keyword.has_key?(entry, :classes) ->
        classes = Keyword.get(entry, :classes)
        Enum.flat_map(classes, fn e -> build_conditional_entry(prop, e) end)

      Keyword.get(entry, :class) != nil ->
        [{prop, Keyword.get(entry, :class)}]

      true ->
        []
    end
  end

  defp build_prop_class_entry(_), do: []

  defp build_conditional_entry(prop, {condition, entry}) when is_list(entry) do
    class = Keyword.get(entry, :class)

    if class == nil do
      [{"#{prop}::#{condition}", :__unset__}]
    else
      [{"#{prop}::#{condition}", class}]
    end
  end

  defp build_conditional_entry(_prop, _), do: []

  @doc """
  Normalizes a class entry to the standard {name, declarations, opts} format.
  Handles legacy format without opts.
  """
  @spec normalize_class_entry(tuple()) :: {atom(), term(), keyword()}
  def normalize_class_entry({name, declarations, opts}), do: {name, declarations, opts}
  def normalize_class_entry({name, declarations}), do: {name, declarations, []}

  @doc false
  def build_dynamic_fns(dynamic_rules, module) do
    Enum.map(dynamic_rules, fn {name, {:__dynamic__, all_props, has_computed}} ->
      fn_name = :"__dynamic_#{name}__"

      quote do
        @doc false
        def unquote(fn_name)(values) do
          LiveStyle.Runtime.Dynamic.compute_var_list(
            unquote(Macro.escape(all_props)),
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
