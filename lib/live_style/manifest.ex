defmodule LiveStyle.Manifest do
  @moduledoc """
  Manifest structure and operations for LiveStyle.

  The manifest stores all CSS artifacts organized by type:
  - vars: CSS custom properties
  - consts: Compile-time constants (no CSS output)
  - keyframes: @keyframes animations
  - position_try: @position-try rules
  - view_transition_classes: View transition classes
  - classes: Style classes (atomic CSS)
  - theme_classes: Variable override themes

  Each entry is keyed by a fully-qualified name like "MyAppWeb.Tokens.color.white"
  for namespaced items or "MyAppWeb.Tokens.spin" for non-namespaced items.

  ## Entry Types

  Each entry type has a corresponding module with constructors and accessors:

  - `LiveStyle.Manifest.VarEntry` - CSS custom properties
  - `LiveStyle.Manifest.KeyframesEntry` - @keyframes animations
  - `LiveStyle.Manifest.ThemeClassEntry` - Theme class variable overrides
  - `LiveStyle.Manifest.PositionTryEntry` - @position-try rules
  - `LiveStyle.Manifest.ViewTransitionClassEntry` - View transition classes
  - `LiveStyle.Manifest.ClassEntry` - Style classes (static and dynamic)
  """

  alias LiveStyle.Manifest.{
    ClassEntry,
    KeyframesEntry,
    PositionTryEntry,
    ThemeClassEntry,
    VarEntry,
    ViewTransitionClassEntry
  }

  # Increment this when the manifest format changes to trigger regeneration.
  # This ensures stale manifests from previous versions are cleared.
  @current_version 9

  @type var_entry :: VarEntry.t()
  @type const_entry :: String.t()
  @type keyframes_entry :: KeyframesEntry.t()
  @type position_try_entry :: PositionTryEntry.t()
  @type view_transition_class_entry :: ViewTransitionClassEntry.t()
  @type class_entry :: ClassEntry.t()
  @type theme_class_entry :: ThemeClassEntry.t()

  # Collections are map-backed internally for fast put/get operations. Use
  # `entries/2` when deterministic sorted traversal is needed.
  @type t :: %{
          version: pos_integer(),
          vars: %{optional(String.t()) => var_entry()},
          consts: %{optional(String.t()) => const_entry()},
          keyframes: %{optional(String.t()) => keyframes_entry()},
          position_try: %{optional(String.t()) => position_try_entry()},
          view_transition_classes: %{optional(String.t()) => view_transition_class_entry()},
          classes: %{optional(String.t()) => class_entry()},
          theme_classes: %{optional(String.t()) => theme_class_entry()},
          module_hashes: %{optional(module()) => binary()}
        }

  @type serializable_t :: %{
          version: pos_integer(),
          vars: [{String.t(), var_entry()}],
          consts: [{String.t(), const_entry()}],
          keyframes: [{String.t(), keyframes_entry()}],
          position_try: [{String.t(), position_try_entry()}],
          view_transition_classes: [{String.t(), view_transition_class_entry()}],
          classes: [{String.t(), class_entry()}],
          theme_classes: [{String.t(), theme_class_entry()}],
          module_hashes: [{module(), binary()}]
        }

  @collections [
    :vars,
    :consts,
    :keyframes,
    :position_try,
    :view_transition_classes,
    :classes,
    :theme_classes,
    :module_hashes
  ]

  @doc """
  Returns the current manifest version.
  """
  @spec current_version() :: pos_integer()
  def current_version, do: @current_version

  @spec empty() :: t()
  def empty do
    %{
      version: @current_version,
      vars: %{},
      consts: %{},
      keyframes: %{},
      position_try: %{},
      view_transition_classes: %{},
      classes: %{},
      theme_classes: %{},
      module_hashes: %{}
    }
  end

  @doc """
  Checks if the manifest version is current.
  """
  @spec current?(t()) :: boolean()
  def current?(%{version: version}), do: version == @current_version
  def current?(_), do: false

  @spec ensure_keys(term()) :: t()
  def ensure_keys(manifest) when is_map(manifest) do
    # If manifest version doesn't match current, discard old data and return fresh
    # This handles format changes that would otherwise cause runtime errors
    if current?(manifest) do
      manifest
      |> struct_merge(empty())
      |> normalize_collections()
    else
      old_version = Map.get(manifest, :version, "unknown")

      require Logger

      Logger.warning(
        "LiveStyle: Manifest version mismatch (found v#{old_version}, expected v#{@current_version}). " <>
          "Discarding old manifest and regenerating CSS."
      )

      empty()
    end
  end

  def ensure_keys(_manifest), do: empty()

  @spec key(module(), atom()) :: String.t()
  def key(module, name), do: "#{to_string(module)}.#{name}"

  @doc """
  Returns a deterministic sorted entry list for a collection.
  """
  @spec entries(t(), atom()) :: list()
  def entries(manifest, collection) when collection in @collections do
    manifest
    |> Map.get(collection, %{})
    |> sorted_entries()
  end

  @doc """
  Returns the number of entries in a collection.
  """
  @spec count(t(), atom()) :: non_neg_integer()
  def count(manifest, collection) when collection in @collections do
    case Map.get(manifest, collection, %{}) do
      entries when is_map(entries) -> map_size(entries)
      entries when is_list(entries) -> length(entries)
      _ -> 0
    end
  end

  @doc """
  Converts the manifest to a deterministic list-backed representation for disk.
  """
  @spec to_serializable(t()) :: serializable_t()
  def to_serializable(manifest) do
    Enum.reduce(@collections, manifest, fn collection, acc ->
      Map.put(acc, collection, entries(acc, collection))
    end)
  end

  # Entry helpers - all use sorted list operations for deterministic ordering
  def put_var(manifest, key, entry), do: put_entry(manifest, :vars, key, entry)
  def get_var(manifest, key), do: get_entry(manifest, :vars, key)

  def put_const(manifest, key, entry), do: put_entry(manifest, :consts, key, entry)
  def get_const(manifest, key), do: get_entry(manifest, :consts, key)

  def put_keyframes(manifest, key, entry), do: put_entry(manifest, :keyframes, key, entry)
  def get_keyframes(manifest, key), do: get_entry(manifest, :keyframes, key)

  def put_position_try(manifest, key, entry), do: put_entry(manifest, :position_try, key, entry)
  def get_position_try(manifest, key), do: get_entry(manifest, :position_try, key)

  def put_view_transition_class(manifest, key, entry),
    do: put_entry(manifest, :view_transition_classes, key, entry)

  def get_view_transition_class(manifest, key),
    do: get_entry(manifest, :view_transition_classes, key)

  def put_class(manifest, key, entry), do: put_entry(manifest, :classes, key, entry)
  def get_class(manifest, key), do: get_entry(manifest, :classes, key)

  def put_theme_class(manifest, key, entry), do: put_entry(manifest, :theme_classes, key, entry)
  def get_theme_class(manifest, key), do: get_entry(manifest, :theme_classes, key)

  @doc """
  Stores a module's content hash in the manifest.

  The hash is used by `__mix_recompile__?/0` to detect when a module's
  LiveStyle definitions have changed and it needs to be recompiled.
  """
  @spec put_module_hash(t(), module(), binary()) :: t()
  def put_module_hash(manifest, module, hash) when is_atom(module) and is_binary(hash) do
    put_entry(manifest, :module_hashes, module, hash)
  end

  @doc """
  Gets the stored content hash for a module.

  Returns `nil` if no hash is stored for the module.
  """
  @spec get_module_hash(t(), module()) :: binary() | nil
  def get_module_hash(manifest, module) when is_atom(module) do
    get_entry(manifest, :module_hashes, module)
  end

  defp put_entry(manifest, collection, key, entry) do
    updated =
      manifest
      |> Map.get(collection, %{})
      |> entries_to_map()
      |> Map.put(key, entry)

    Map.put(manifest, collection, updated)
  end

  defp get_entry(manifest, collection, key) do
    manifest
    |> Map.get(collection, %{})
    |> entries_to_map()
    |> Map.get(key)
  end

  defp struct_merge(updates, base) when is_map(base) and is_map(updates) do
    Enum.reduce(updates, base, fn {k, v}, acc ->
      if is_map_key(acc, k), do: %{acc | k => v}, else: acc
    end)
  end

  defp normalize_collections(manifest) do
    Enum.reduce(@collections, manifest, fn collection, acc ->
      Map.update!(acc, collection, &entries_to_map/1)
    end)
  end

  defp entries_to_map(entries) when is_map(entries), do: entries
  defp entries_to_map(entries) when is_list(entries), do: Map.new(entries)
  defp entries_to_map(_entries), do: %{}

  defp sorted_entries(entries) when is_map(entries) do
    Enum.sort_by(entries, fn {key, _entry} -> key end)
  end

  defp sorted_entries(entries) when is_list(entries) do
    Enum.sort_by(entries, fn {key, _entry} -> key end)
  end

  defp sorted_entries(_entries), do: []
end
