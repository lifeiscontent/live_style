defmodule LiveStyle.Compiler.CSS.Classes.Collector do
  @moduledoc false
  # Collects pre-built CSS rules from manifest for rendering.
  # With StyleX model, entries contain pre-built ltr/rtl CSS strings.

  # {class_name, priority, ltr_css, rtl_css}
  @type class_tuple :: {String.t(), non_neg_integer(), String.t(), String.t() | nil}

  @spec collect(LiveStyle.Manifest.t()) :: [class_tuple()]
  def collect(manifest) do
    manifest.classes
    # Already sorted by key in manifest (sorted list storage)
    |> Enum.flat_map(fn {_key, entry} ->
      # Sort atomic_classes by property name for deterministic order
      Keyword.fetch!(entry, :atomic_classes)
      |> Enum.sort_by(fn {prop, _data} -> prop end)
      |> Enum.flat_map(&extract_class_tuples/1)
    end)
    |> Enum.uniq_by(fn {class_name, _, _, _} -> class_name end)
    |> Enum.sort_by(fn {class_name, priority, _, _} -> {priority, class_name} end)
  end

  # Extract class tuples from atomic_classes entries
  defp extract_class_tuples({_property, data}) when is_list(data) do
    cond do
      Keyword.get(data, :unset) == true ->
        []

      Keyword.has_key?(data, :classes) ->
        # Conditional values - extract each variant
        classes = Keyword.get(data, :classes)

        Enum.map(classes, fn {_condition, entry} ->
          build_class_tuple(entry)
        end)

      true ->
        # Simple value
        [build_class_tuple(data)]
    end
  end

  defp build_class_tuple(entry) do
    {
      Keyword.get(entry, :class),
      Keyword.get(entry, :priority, 3000),
      Keyword.get(entry, :ltr),
      Keyword.get(entry, :rtl)
    }
  end
end
