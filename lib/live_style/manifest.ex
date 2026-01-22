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
  @current_version 8

  @type var_entry :: VarEntry.t()
  @type const_entry :: String.t()
  @type keyframes_entry :: KeyframesEntry.t()
  @type position_try_entry :: PositionTryEntry.t()
  @type view_transition_class_entry :: ViewTransitionClassEntry.t()
  @type class_entry :: ClassEntry.t()
  @type theme_class_entry :: ThemeClassEntry.t()

  # All collections use sorted lists of {key, entry} tuples for deterministic ordering
  @type t :: %{
          version: pos_integer(),
          vars: [{String.t(), var_entry()}],
          consts: [{String.t(), const_entry()}],
          keyframes: [{String.t(), keyframes_entry()}],
          position_try: [{String.t(), position_try_entry()}],
          view_transition_classes: [{String.t(), view_transition_class_entry()}],
          classes: [{String.t(), class_entry()}],
          theme_classes: [{String.t(), theme_class_entry()}]
        }

  @doc """
  Returns the current manifest version.
  """
  @spec current_version() :: pos_integer()
  def current_version, do: @current_version

  @spec empty() :: t()
  def empty do
    %{
      version: @current_version,
      vars: [],
      consts: [],
      keyframes: [],
      position_try: [],
      view_transition_classes: [],
      classes: [],
      theme_classes: []
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
      struct_merge(empty(), manifest)
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

  defp struct_merge(base, updates) when is_map(base) and is_map(updates) do
    Enum.reduce(updates, base, fn {k, v}, acc ->
      if is_map_key(acc, k), do: %{acc | k => v}, else: acc
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

  # Private helpers for sorted list operations

  # Insert or update entry in sorted list, maintaining sort order by key
  defp put_entry(manifest, collection, key, entry) do
    list = Map.get(manifest, collection, [])
    updated = sorted_list_put(list, key, entry)
    Map.put(manifest, collection, updated)
  end

  # Get entry from sorted list by key
  defp get_entry(manifest, collection, key) do
    list = Map.get(manifest, collection, [])
    sorted_list_get(list, key)
  end

  # Insert or update in a sorted list, maintaining sort order
  defp sorted_list_put(list, key, entry) do
    case sorted_list_find_index(list, key) do
      {:found, index} ->
        List.replace_at(list, index, {key, entry})

      {:insert_at, index} ->
        List.insert_at(list, index, {key, entry})
    end
  end

  # Get value from sorted list by key (linear search, but could use binary search)
  defp sorted_list_get(list, key) do
    case List.keyfind(list, key, 0) do
      {^key, entry} -> entry
      nil -> nil
    end
  end

  # Find index where key exists or should be inserted
  defp sorted_list_find_index(list, key) do
    find_index(list, key, 0)
  end

  defp find_index([], _key, index), do: {:insert_at, index}

  defp find_index([{k, _} | _rest], key, index) when key < k, do: {:insert_at, index}
  defp find_index([{k, _} | _rest], key, index) when key == k, do: {:found, index}
  defp find_index([_ | rest], key, index), do: find_index(rest, key, index + 1)
end
