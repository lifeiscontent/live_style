defmodule LiveStyle.Runtime.StyleMerger do
  @moduledoc false

  alias LiveStyle.Runtime.PropertyMerger

  defstruct merged_props: [],
            var_styles: [],
            ordered_classes: [],
            prop_classes_by_key: %{}

  @type state :: %__MODULE__{
          merged_props: LiveStyle.Attrs.prop_classes(),
          var_styles: [keyword()],
          ordered_classes: [String.t()],
          prop_classes_by_key: %{optional(atom() | String.t()) => String.t()}
        }

  @spec new_state() :: state()
  def new_state, do: %__MODULE__{}

  @spec merge_resolved(
          {:static, LiveStyle.Attrs.prop_classes()}
          | {:dynamic, LiveStyle.Attrs.prop_classes(), keyword()}
          | :skip,
          state()
        ) :: state()
  def merge_resolved({:static, prop_classes}, state) do
    merge_prop_classes(prop_classes, state)
  end

  def merge_resolved({:dynamic, prop_classes, var_list}, state) do
    prop_classes
    |> merge_prop_classes(state)
    |> append_var_list(var_list)
  end

  def merge_resolved(:skip, state), do: state

  @spec merge_resolved_refs(list(), String.t() | nil) :: LiveStyle.Attrs.t()
  def merge_resolved_refs(resolved_refs, extra_styles \\ nil) do
    resolved_refs
    |> Enum.reduce(new_state(), &merge_resolved/2)
    |> to_attrs(extra_styles)
  end

  @spec merge_attrs(LiveStyle.Attrs.t(), state()) :: state()
  def merge_attrs(
        %LiveStyle.Attrs{prop_classes: prop_classes, class: class},
        state
      )
      when is_list(prop_classes) and prop_classes != [] do
    prop_classes
    |> merge_prop_classes(state)
    |> append_extra_classes(class, prop_classes)
  end

  def merge_attrs(%LiveStyle.Attrs{class: class}, state)
      when is_binary(class) and class != "" do
    append_class_string(state, class)
  end

  def merge_attrs(%LiveStyle.Attrs{}, state), do: state

  @spec append_class_string(state(), String.t()) :: state()
  def append_class_string(%__MODULE__{ordered_classes: ordered_classes} = state, class_string) do
    %{state | ordered_classes: ordered_classes ++ split_class_string(class_string)}
  end

  @spec to_attrs(state(), String.t() | nil) :: LiveStyle.Attrs.t()
  def to_attrs(
        %__MODULE__{
          merged_props: merged_props,
          var_styles: var_styles,
          ordered_classes: ordered_classes
        },
        extra_styles
      ) do
    class_string =
      ordered_classes
      |> Enum.uniq()
      |> Enum.join(" ")

    %LiveStyle.Attrs{
      class: class_string,
      style: build_style_string(var_styles, extra_styles),
      prop_classes: merged_props
    }
  end

  @spec merge_style_strings(String.t() | nil, String.t() | nil) :: String.t() | nil
  def merge_style_strings(nil, nil), do: nil
  def merge_style_strings(nil, extra) when is_binary(extra), do: extra
  def merge_style_strings(dynamic, nil) when is_binary(dynamic), do: dynamic

  def merge_style_strings(dynamic, extra)
      when is_binary(dynamic) and is_binary(extra) do
    "#{dynamic}; #{extra}"
  end

  defp merge_prop_classes(prop_classes, %__MODULE__{} = state) do
    merged = PropertyMerger.merge(prop_classes, state.merged_props)

    {new_class_order, new_prop_classes_by_key} =
      apply_prop_classes(prop_classes, state.ordered_classes, state.prop_classes_by_key)

    %{
      state
      | merged_props: merged,
        ordered_classes: new_class_order,
        prop_classes_by_key: new_prop_classes_by_key
    }
  end

  defp append_var_list(%__MODULE__{var_styles: var_styles} = state, var_list)
       when is_list(var_list) do
    %{state | var_styles: [var_list | var_styles]}
  end

  defp append_extra_classes(state, class, prop_classes) do
    extra_from_attrs = extract_extra_classes(class, prop_classes)

    Enum.reduce(extra_from_attrs, state, fn class_name, acc ->
      append_class_string(acc, class_name)
    end)
  end

  defp extract_extra_classes(class, prop_classes) when is_binary(class) and class != "" do
    prop_class_values = MapSet.new(Enum.map(prop_classes, fn {_prop, cls} -> cls end))

    class
    |> String.split(" ", trim: true)
    |> Enum.reject(&MapSet.member?(prop_class_values, &1))
  end

  defp extract_extra_classes(_, _), do: []

  defp build_style_string([], nil), do: nil
  defp build_style_string([], extra) when is_binary(extra), do: extra

  defp build_style_string(var_styles, nil) do
    var_styles
    |> Enum.reverse()
    |> Enum.reduce([], &merge_var_list/2)
    |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)
  end

  defp build_style_string(var_styles, extra) when is_binary(extra) do
    var_string =
      var_styles
      |> Enum.reverse()
      |> Enum.reduce([], &merge_var_list/2)
      |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)

    if var_string == "" do
      extra
    else
      "#{var_string}; #{extra}"
    end
  end

  defp merge_var_list(new_vars, acc) when is_list(new_vars) do
    Enum.reduce(new_vars, acc, fn {key, value}, inner_acc ->
      List.keystore(inner_acc, key, 0, {key, value})
    end)
  end

  defp split_class_string(class_string) when is_binary(class_string) do
    String.split(class_string, " ", trim: true)
  end

  defp apply_prop_classes(prop_classes, class_order, prop_classes_by_key)
       when is_list(prop_classes) do
    Enum.reduce(prop_classes, {class_order, prop_classes_by_key}, fn
      {prop_key, :__unset__}, {order_acc, prop_map_acc} ->
        case Map.pop(prop_map_acc, prop_key) do
          {nil, updated_map} ->
            {order_acc, updated_map}

          {old_class, updated_map} ->
            {remove_last(order_acc, old_class), updated_map}
        end

      {prop_key, class_name}, {order_acc, prop_map_acc}
      when is_binary(class_name) and class_name != "" ->
        {trimmed_order, updated_map} =
          case Map.pop(prop_map_acc, prop_key) do
            {nil, map_without_prop} ->
              {order_acc, map_without_prop}

            {old_class, map_without_prop} ->
              {remove_last(order_acc, old_class), map_without_prop}
          end

        {trimmed_order ++ [class_name], Map.put(updated_map, prop_key, class_name)}

      _entry, acc ->
        acc
    end)
  end

  defp remove_last(list, target) do
    list
    |> Enum.reverse()
    |> remove_first_reversed(target)
    |> Enum.reverse()
  end

  defp remove_first_reversed([target | rest], target), do: rest

  defp remove_first_reversed([head | rest], target),
    do: [head | remove_first_reversed(rest, target)]

  defp remove_first_reversed([], _target), do: []
end
