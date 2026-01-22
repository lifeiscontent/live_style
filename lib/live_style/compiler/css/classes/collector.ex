defmodule LiveStyle.Compiler.CSS.Classes.Collector do
  @moduledoc false
  # Collects pre-built CSS rules from manifest for rendering.
  # With StyleX model, entries contain pre-built ltr/rtl CSS strings.

  # {class_name, property, priority, ltr_css, rtl_css}
  # Property is included for proper CSS cascade ordering (StyleX parity).
  # When priorities are equal, properties are sorted alphabetically so that
  # later properties in alphabetical order override earlier ones in CSS cascade.
  @type class_tuple :: {String.t(), String.t(), non_neg_integer(), String.t(), String.t() | nil}

  @spec collect(LiveStyle.Manifest.t()) :: [class_tuple()]
  def collect(manifest) do
    usage = LiveStyle.Storage.read_usage()

    manifest.classes
    # Filter by usage (StyleX-style tree shaking)
    |> Enum.filter(fn {key, _entry} ->
      key_used?(key, usage)
    end)
    # Already sorted by key in manifest (sorted list storage)
    |> Enum.flat_map(fn {_key, entry} ->
      # Sort atomic_classes by property name for deterministic order
      Keyword.fetch!(entry, :atomic_classes)
      |> Enum.sort_by(fn {prop, _data} -> prop end)
      |> Enum.flat_map(&extract_class_tuples/1)
    end)
    |> Enum.uniq_by(fn {class_name, _, _, _, _} -> class_name end)
    # Sort by {priority, property, class_name} for proper CSS cascade.
    # This matches StyleX's non-legacy sorting behavior where properties
    # are sorted alphabetically within the same priority level.
    |> Enum.sort_by(fn {class_name, property, priority, _, _} ->
      {priority, property, class_name}
    end)
  end

  # Check if a class key is used (for tree shaking)
  defp key_used?(key, usage) do
    LiveStyle.UsageManifest.key_used?(usage, key)
  end

  # Extract class tuples from atomic_classes entries
  defp extract_class_tuples({property, data}) when is_list(data) do
    cond do
      Keyword.get(data, :unset) == true ->
        []

      Keyword.has_key?(data, :classes) ->
        # Conditional values - extract each variant
        classes = Keyword.get(data, :classes)

        Enum.map(classes, fn {_condition, entry} ->
          build_class_tuple(property, entry)
        end)

      true ->
        # Simple value
        [build_class_tuple(property, data)]
    end
  end

  defp build_class_tuple(property, entry) do
    {
      Keyword.get(entry, :class),
      property,
      Keyword.get(entry, :priority, 3000),
      Keyword.get(entry, :ltr),
      Keyword.get(entry, :rtl)
    }
  end
end
