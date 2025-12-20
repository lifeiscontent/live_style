defmodule LiveStyle.Runtime do
  @moduledoc """
  Runtime helpers for LiveStyle style resolution.

  This module handles runtime operations for resolving style references:
  - Class string resolution from refs
  - Property-based merging (StyleX behavior)
  - Dynamic rule processing
  - Cross-module reference resolution

  Note: Class reference validation is done at compile time by the
  css_class/1 and css/1 macros in LiveStyle.
  """

  alias LiveStyle.Config
  alias LiveStyle.Manifest
  alias LiveStyle.Value

  @doc """
  Resolve a list of refs into a class string.

  Later refs override earlier ones (StyleX merge behavior).
  Validation is done at compile time by the css_class/1 macro.
  """
  @spec resolve_class_string(module(), list(), map(), list()) :: String.t()
  def resolve_class_string(module, refs, _class_strings, _dynamic_names) when is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    # Build a map of property_key -> class_name
    # Later refs override earlier ones (StyleX merge behavior)
    merged =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce(%{}, fn ref, acc ->
        merge_ref_classes(module, ref, property_classes_map, acc)
      end)

    # Return unique class names in order
    # Filter out any :__unset__ values (shouldn't exist but defensive)
    merged
    |> Map.values()
    |> Enum.reject(&(&1 == :__unset__ or &1 == nil))
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  @doc """
  Resolve a list of refs into an Attrs struct with class and style.

  Handles both static rules and dynamic rules with CSS variables.
  Validation is done at compile time by the css/1 macro.
  """
  @spec resolve_attrs(module(), list(), map(), list()) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, _class_strings, _dynamic_names) when is_list(refs) do
    property_classes_map = module.__live_style__(:property_classes)

    # Use property-based merging to correctly handle :__unset__ values (StyleX behavior)
    # This ensures that nil values properly "unset" properties
    {merged_props, var_styles} =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce({%{}, []}, fn ref, {props_acc, vars_acc} ->
        resolve_ref_with_props(module, ref, property_classes_map)
        |> merge_resolved_ref(props_acc, vars_acc)
      end)

    # Build class string from merged properties
    # Filter out :__unset__ values and nil classes
    class_string =
      merged_props
      |> Map.values()
      |> Enum.reject(&(&1 == :__unset__ or &1 == nil or &1 == ""))
      |> Enum.uniq()
      |> Enum.join(" ")

    # Merge all CSS variable maps and convert to style string
    style_string =
      case var_styles do
        [] ->
          nil

        _ ->
          var_styles
          |> Enum.reverse()
          |> Enum.reduce(%{}, &Map.merge(&2, &1))
          |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)
      end

    %LiveStyle.Attrs{class: class_string, style: style_string}
  end

  # Merge a resolved reference into the accumulator
  defp merge_resolved_ref({:static, prop_classes}, props_acc, vars_acc) do
    merged = Enum.reduce(prop_classes, props_acc, &merge_prop_class/2)
    {merged, vars_acc}
  end

  defp merge_resolved_ref({:dynamic, class_string, var_map}, props_acc, vars_acc) do
    # Dynamic rules don't participate in property-based merging
    # They add their class directly and provide CSS variables
    dyn_key = "__dynamic_#{:erlang.unique_integer([:positive])}__"
    {Map.put(props_acc, dyn_key, class_string), [var_map | vars_acc]}
  end

  defp merge_resolved_ref(:skip, props_acc, vars_acc), do: {props_acc, vars_acc}

  # Merge a single property class - handle :__unset__ values
  defp merge_prop_class({prop, :__unset__}, acc), do: Map.delete(acc, prop)
  defp merge_prop_class({prop, class}, acc), do: Map.put(acc, prop, class)

  @doc """
  Process a dynamic rule at runtime.

  Dynamic rules generate:
  1. Static CSS classes that reference CSS variables (var(--x-...))
  2. At runtime, we return the class + a map of CSS variables to set

  This follows the StyleX pattern where static CSS uses var() references
  and runtime just sets the variable values via inline style.
  """
  @spec process_dynamic_rule(list(), list(), term(), module(), atom(), boolean()) ::
          {String.t(), map()}
  def process_dynamic_rule(all_props, _param_names, values, module, name, has_computed) do
    # Get the static class string for this dynamic rule
    # (generated at compile time with var() references)
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    class_string =
      case Manifest.get_class(manifest, key) do
        %{class_string: cs} -> cs
        nil -> ""
      end

    # Build a list of values
    values_list = if is_list(values), do: values, else: [values]

    prefix = Config.class_name_prefix()

    var_map =
      if has_computed do
        # For computed values, call the module's compute function
        # to get the actual CSS values
        compute_fn_name = :"__compute_#{name}__"
        declarations = apply(module, compute_fn_name, [values_list])

        # Build CSS variables from the resulting declarations
        Map.new(declarations, fn {prop, value} ->
          {"--#{prefix}-#{Value.to_css_property(prop)}", format_css_value(value)}
        end)
      else
        # Simple bindings - map params to props directly
        all_props
        |> Enum.zip(values_list)
        |> Map.new(fn {prop, value} ->
          {"--#{prefix}-#{Value.to_css_property(prop)}", format_css_value(value)}
        end)
      end

    {class_string, var_map}
  end

  # Merge classes from a ref into the accumulator, with later properties overriding earlier
  # StyleX behavior: :__unset__ sentinel value indicates property should be removed
  defp merge_ref_classes(_module, ref, property_classes_map, acc) when is_atom(ref) do
    prop_classes = Map.get(property_classes_map, ref, %{})

    # For each property in prop_classes:
    # - If value is :__unset__, delete the property from acc
    # - Otherwise, merge (override) the property
    Enum.reduce(prop_classes, acc, fn
      {prop, :__unset__}, acc_inner ->
        # Unset value - remove this property from the accumulator
        Map.delete(acc_inner, prop)

      {prop, class}, acc_inner ->
        # Regular value - override the property
        Map.put(acc_inner, prop, class)
    end)
  end

  defp merge_ref_classes(_module, {other_module, name}, _property_classes_map, acc)
       when is_atom(other_module) and is_atom(name) do
    # Cross-module static rule reference
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Map.get(other_prop_classes, name, %{})

        # Handle :__unset__ sentinel values for cross-module references
        Enum.reduce(prop_classes, acc, fn
          {prop, :__unset__}, acc_inner ->
            Map.delete(acc_inner, prop)

          {prop, class}, acc_inner ->
            Map.put(acc_inner, prop, class)
        end)

      _ ->
        acc
    end
  end

  defp merge_ref_classes(_module, _ref, _property_classes_map, acc), do: acc

  # resolve_ref_with_props - returns property classes for proper merging
  # Returns {:static, prop_classes} | {:dynamic, class_string, var_map} | :skip
  defp resolve_ref_with_props(_module, ref, property_classes_map) when is_atom(ref) do
    prop_classes = Map.get(property_classes_map, ref, %{})
    {:static, prop_classes}
  end

  defp resolve_ref_with_props(_module, {other_module, name}, _property_classes_map)
       when is_atom(other_module) and is_atom(name) do
    case Atom.to_string(other_module) do
      <<"Elixir.", _::binary>> ->
        other_prop_classes = other_module.__live_style__(:property_classes)
        prop_classes = Map.get(other_prop_classes, name, %{})
        {:static, prop_classes}

      _ ->
        :skip
    end
  end

  defp resolve_ref_with_props(module, {name, args}, _property_classes_map) when is_atom(name) do
    dynamic_names = module.__live_style__(:dynamic_names)

    if name in dynamic_names do
      fn_name = :"__dynamic_#{name}__"
      {class_string, var_map} = apply(module, fn_name, [args])
      {:dynamic, class_string, var_map || %{}}
    else
      # Static rule with args (shouldn't happen, but handle it)
      prop_classes = module.__live_style__(:property_classes) |> Map.get(name, %{})
      {:static, prop_classes}
    end
  end

  defp resolve_ref_with_props(_module, _ref, _property_classes_map), do: :skip

  defp format_css_value(value) when is_number(value), do: "#{value}"
  defp format_css_value(value) when is_binary(value), do: value
  defp format_css_value(value), do: to_string(value)
end
