defmodule LiveStyle.Compiler.ModuleHash do
  @moduledoc """
  Computes content hashes for `__mix_recompile__?` detection.

  This module provides hash computation for LiveStyle modules, enabling
  fine-grained recompilation detection. When a module's LiveStyle definitions
  change, its hash changes, triggering recompilation via Mix's standard
  `__mix_recompile__?` callback.

  ## How It Works

  1. At compile time, `compute/8` creates a hash of all LiveStyle definitions
  2. The hash is stored in the manifest via `Manifest.put_module_hash/3`
  3. When Mix checks if recompilation is needed, `__mix_recompile__?` compares
     the stored hash against the current computed hash
  4. If they differ (or no stored hash exists), the module is recompiled

  This follows the pattern used by Gettext for PO file change detection.
  """

  alias LiveStyle.Compiler.ModuleData

  @doc """
  Computes a content hash for a module's LiveStyle definitions.

  All inputs are normalized and sorted before hashing to ensure
  deterministic output regardless of definition order.

  Returns a 16-byte MD5 hash as a binary.
  """
  @spec compute(
          module :: module(),
          classes :: list(),
          vars :: list(),
          consts :: list(),
          keyframes :: list(),
          theme_classes :: list(),
          view_transition_classes :: list(),
          position_try :: list()
        ) :: binary()
  def compute(
        module,
        classes,
        vars,
        consts,
        keyframes,
        theme_classes,
        view_transition_classes,
        position_try
      ) do
    # Normalize all inputs: sort by key/name for deterministic ordering
    normalized = {
      module,
      normalize_list(classes),
      normalize_list(vars),
      normalize_list(consts),
      normalize_list(keyframes),
      normalize_list(theme_classes),
      normalize_list(view_transition_classes),
      normalize_list(position_try)
    }

    # Convert to binary and hash
    :crypto.hash(:md5, :erlang.term_to_binary(normalized))
  end

  @doc """
  Gets the stored hash for a module.

  Returns `nil` if no hash is stored (e.g., clean build or new module).

  This reads from the module's per-module data file instead of the full
  manifest, making `__mix_recompile__?` checks much faster. Each module
  has its own file, so no locking is needed.
  """
  @spec get_stored_hash(module()) :: binary() | nil
  def get_stored_hash(module) when is_atom(module) do
    case ModuleData.read(module) do
      nil -> nil
      data -> Map.get(data, :module_hash)
    end
  end

  # Normalize a list by sorting it. For keyword lists and tuples,
  # we sort by the first element (key/name).
  defp normalize_list(list) when is_list(list) do
    list
    |> Enum.sort_by(fn
      {key, _value} -> key
      {key, _value, _opts} -> key
      other -> other
    end)
  end
end
