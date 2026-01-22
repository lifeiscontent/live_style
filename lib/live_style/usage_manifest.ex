defmodule LiveStyle.UsageManifest do
  @moduledoc """
  Tracks which LiveStyle classes are actually used in code.

  This module provides a data structure for tracking class usage at compile time,
  enabling tree-shaking of unused styles (StyleX-style optimization).

  ## Usage Tracking

  When `css/1` macros expand, they record which classes are referenced.
  This allows the CSS generator to emit only styles that are actually used.

  ## Data Structure

  Usage is stored as a MapSet of `{module, class_name}` tuples where:
  - `module` is the defining module (e.g., `MyApp.Button`)
  - `class_name` is the atom name (e.g., `:primary`)

  ## Example

      usage = UsageManifest.empty()
      usage = UsageManifest.record_usage(usage, MyApp.Button, :primary)
      UsageManifest.used?(usage, MyApp.Button, :primary)  #=> true
  """

  @type t :: MapSet.t({module(), atom()})

  @doc """
  Returns an empty usage manifest.
  """
  @spec empty() :: t()
  def empty, do: MapSet.new()

  @doc """
  Records that a class is used.

  ## Parameters

  - `usage` - The current usage manifest
  - `module` - The module defining the class
  - `class_name` - The atom name of the class

  ## Returns

  Updated usage manifest with the class recorded.
  """
  @spec record_usage(t(), module(), atom()) :: t()
  def record_usage(usage, module, class_name) when is_atom(module) and is_atom(class_name) do
    MapSet.put(usage, {module, class_name})
  end

  @doc """
  Checks if a class is used.

  ## Parameters

  - `usage` - The usage manifest
  - `module` - The module defining the class
  - `class_name` - The atom name of the class

  ## Returns

  `true` if the class has been recorded as used, `false` otherwise.
  """
  @spec used?(t(), module(), atom()) :: boolean()
  def used?(usage, module, class_name) when is_atom(module) and is_atom(class_name) do
    MapSet.member?(usage, {module, class_name})
  end

  @doc """
  Checks if a class is used by its manifest key.

  Manifest keys have the format "Elixir.Module.class_name".

  ## Parameters

  - `usage` - The usage manifest
  - `key` - The manifest key (e.g., "Elixir.MyApp.Button.primary")

  ## Returns

  `true` if the class has been recorded as used, `false` otherwise.
  """
  @spec key_used?(t(), String.t()) :: boolean()
  def key_used?(usage, key) when is_binary(key) do
    case parse_key(key) do
      {:ok, module, class_name} -> used?(usage, module, class_name)
      :error -> false
    end
  end

  @doc """
  Merges two usage manifests.

  ## Parameters

  - `usage1` - First usage manifest
  - `usage2` - Second usage manifest

  ## Returns

  A new usage manifest containing all entries from both.
  """
  @spec merge(t(), t()) :: t()
  def merge(usage1, usage2) do
    MapSet.union(usage1, usage2)
  end

  @doc """
  Converts usage manifest to a list of `{module, class_name}` tuples.
  """
  @spec to_list(t()) :: [{module(), atom()}]
  def to_list(usage), do: MapSet.to_list(usage)

  @doc """
  Returns the number of recorded usages.
  """
  @spec size(t()) :: non_neg_integer()
  def size(usage), do: MapSet.size(usage)

  @doc """
  Marks all classes from a manifest as used.

  This is useful for testing where you want to verify CSS output
  without needing to explicitly call `css/1` for each class.

  Similar to StyleX's `treeshakeCompensation` option.

  ## Parameters

  - `usage` - The current usage manifest
  - `manifest` - The LiveStyle manifest containing class definitions

  ## Returns

  Updated usage manifest with all classes marked as used.
  """
  @spec mark_all_used(t(), map()) :: t()
  def mark_all_used(usage, manifest) do
    classes = Map.get(manifest, :classes, [])

    Enum.reduce(classes, usage, fn {key, _entry}, acc ->
      case parse_key(key) do
        {:ok, module, class_name} -> record_usage(acc, module, class_name)
        :error -> acc
      end
    end)
  end

  # Parse a manifest key into {module, class_name}
  # Key format: "Elixir.MyApp.Button.primary"
  defp parse_key(key) do
    # Split by "." and find where the class name is
    # The last part is the class name, everything before is the module
    parts = String.split(key, ".")

    case parts do
      [_ | _] = parts when length(parts) >= 2 ->
        {module_parts, [class_name_str]} = Enum.split(parts, -1)
        module_str = Enum.join(module_parts, ".")

        try do
          module = String.to_existing_atom(module_str)
          class_name = String.to_existing_atom(class_name_str)
          {:ok, module, class_name}
        rescue
          ArgumentError -> :error
        end

      _ ->
        :error
    end
  end
end
