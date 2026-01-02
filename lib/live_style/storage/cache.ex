defmodule LiveStyle.Storage.Cache do
  @moduledoc """
  ETS-based cache that serves as the primary manifest storage during compilation.

  This module provides a fast in-memory storage layer that eliminates file lock
  contention during parallel compilation. Each entry is stored with its own key
  in ETS, allowing lock-free concurrent writes from multiple compilation processes.

  ## How it works

  1. On first read, loads manifest from file into ETS (if file exists)
  2. Writes store individual entries (classes, vars, etc.) with unique keys
  3. Reads aggregate all entries into a manifest structure
  4. `persist/0` writes aggregated manifest to file

  ## Storage Format

  Entries are stored as:
  - `{:class, key}` => class_entry
  - `{:var, key}` => var_entry
  - `{:theme, key}` => theme_entry
  - etc.

  ## Usage

  This is used internally by `LiveStyle.Storage`. You don't need to
  interact with it directly.
  """

  @table_name :live_style_manifest_cache
  @initialized_key :__initialized__

  @doc """
  Initializes the ETS cache table if it doesn't exist.

  Delegates to TableOwner.ensure_table/0 which handles table creation.
  During compilation (before app starts), creates a fallback table.
  At runtime, the TableOwner GenServer owns the table.
  """
  def init do
    LiveStyle.Storage.TableOwner.ensure_table()
  end

  @doc """
  Returns whether the cache has been populated from file.
  """
  def initialized? do
    init()

    table = :ets.whereis(@table_name)

    if table == :undefined do
      false
    else
      case :ets.lookup(table, @initialized_key) do
        [{@initialized_key, true}] -> true
        _ -> false
      end
    end
  end

  @doc """
  Atomically marks the cache as initialized.
  Returns true if this call did the initialization, false if already initialized.
  Uses insert_new for atomic check-and-set.
  """
  def mark_initialized do
    init()
    :ets.insert_new(@table_name, {@initialized_key, true})
  end

  @doc """
  Gets an aggregated manifest from all cached entries.
  Returns nil if cache is not initialized or table doesn't exist.
  """
  def get_manifest do
    init()

    table = :ets.whereis(@table_name)

    if table == :undefined do
      nil
    else
      try do
        if initialized?() do
          aggregate_manifest()
        else
          nil
        end
      rescue
        # Table was deleted between whereis and lookup
        ArgumentError -> nil
      end
    end
  end

  @doc """
  Populates the cache from a manifest structure.
  Used when loading from file.

  Returns :ok if population succeeded, or :already_initialized if another
  process beat us to it (in which case, existing cache is kept).
  """
  def populate_from_manifest(manifest) do
    init()

    # Atomically try to mark as initialized FIRST
    # This prevents race conditions where multiple processes load from file
    if mark_initialized() do
      # We won the race - populate the cache
      # Collections are sorted lists of {key, entry} tuples
      insert_entries(:class, manifest.classes)
      insert_entries(:var, manifest.vars)
      insert_entries(:theme, manifest.themes)
      insert_entries(:const, manifest.consts)
      insert_entries(:keyframes, manifest.keyframes)
      insert_entries(:view_transition, manifest.view_transitions)
      insert_entries(:position_try, manifest.position_try)
      :ok
    else
      # Another process already initialized - our entries will be added
      # individually by the caller, so this is fine
      :already_initialized
    end
  end

  defp insert_entries(_type, nil), do: :ok

  defp insert_entries(type, entries) do
    for {key, entry} <- entries do
      :ets.insert(@table_name, {{type, key}, entry})
    end

    :ok
  end

  @doc """
  Stores a single class entry.
  """
  def put_class(key, entry) do
    init()
    :ets.insert(@table_name, {{:class, key}, entry})
    :ok
  end

  @doc """
  Gets a single class entry.
  """
  def get_class(key) do
    init()

    case :ets.lookup(@table_name, {:class, key}) do
      [{{:class, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single var entry.
  """
  def put_var(key, entry) do
    init()
    :ets.insert(@table_name, {{:var, key}, entry})
    :ok
  end

  @doc """
  Gets a single var entry.
  """
  def get_var(key) do
    init()

    case :ets.lookup(@table_name, {:var, key}) do
      [{{:var, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single theme entry.
  """
  def put_theme(key, entry) do
    init()
    :ets.insert(@table_name, {{:theme, key}, entry})
    :ok
  end

  @doc """
  Gets a single theme entry.
  """
  def get_theme(key) do
    init()

    case :ets.lookup(@table_name, {:theme, key}) do
      [{{:theme, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single const entry.
  """
  def put_const(key, entry) do
    init()
    :ets.insert(@table_name, {{:const, key}, entry})
    :ok
  end

  @doc """
  Gets a single const entry.
  """
  def get_const(key) do
    init()

    case :ets.lookup(@table_name, {:const, key}) do
      [{{:const, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single keyframes entry.
  """
  def put_keyframes(key, entry) do
    init()
    :ets.insert(@table_name, {{:keyframes, key}, entry})
    :ok
  end

  @doc """
  Gets a single keyframes entry.
  """
  def get_keyframes(key) do
    init()

    case :ets.lookup(@table_name, {:keyframes, key}) do
      [{{:keyframes, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single view transition entry.
  """
  def put_view_transition(key, entry) do
    init()
    :ets.insert(@table_name, {{:view_transition, key}, entry})
    :ok
  end

  @doc """
  Gets a single view transition entry.
  """
  def get_view_transition(key) do
    init()

    case :ets.lookup(@table_name, {:view_transition, key}) do
      [{{:view_transition, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Stores a single position try entry.
  """
  def put_position_try(key, entry) do
    init()
    :ets.insert(@table_name, {{:position_try, key}, entry})
    :ok
  end

  @doc """
  Gets a single position try entry.
  """
  def get_position_try(key) do
    init()

    case :ets.lookup(@table_name, {:position_try, key}) do
      [{{:position_try, ^key}, entry}] -> entry
      [] -> nil
    end
  end

  @doc """
  Invalidates the cache, forcing the next read to initialize fresh.
  """
  def invalidate do
    if :ets.whereis(@table_name) != :undefined do
      :ets.delete_all_objects(@table_name)
    end

    :ok
  end

  @doc """
  Returns cache statistics for debugging.
  """
  def stats do
    init()

    if initialized?() do
      manifest = aggregate_manifest()

      %{
        initialized: true,
        classes: length(manifest.classes || []),
        vars: length(manifest.vars || []),
        themes: length(manifest.themes || []),
        consts: length(manifest.consts || []),
        keyframes: length(manifest.keyframes || [])
      }
    else
      %{initialized: false}
    end
  end

  # Aggregate all entries back into a manifest structure
  # Returns sorted lists for deterministic ordering
  defp aggregate_manifest do
    init()

    # Collect all entries by type
    all_entries = :ets.tab2list(@table_name)

    classes =
      all_entries
      |> Enum.filter(fn
        {{:class, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:class, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    vars =
      all_entries
      |> Enum.filter(fn
        {{:var, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:var, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    themes =
      all_entries
      |> Enum.filter(fn
        {{:theme, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:theme, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    consts =
      all_entries
      |> Enum.filter(fn
        {{:const, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:const, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    keyframes =
      all_entries
      |> Enum.filter(fn
        {{:keyframes, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:keyframes, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    view_transitions =
      all_entries
      |> Enum.filter(fn
        {{:view_transition, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:view_transition, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    position_try =
      all_entries
      |> Enum.filter(fn
        {{:position_try, _key}, _entry} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:position_try, key}, entry} -> {key, entry} end)
      |> Enum.sort_by(fn {key, _} -> key end)

    %{
      version: LiveStyle.Manifest.current_version(),
      classes: classes,
      vars: vars,
      themes: themes,
      consts: consts,
      keyframes: keyframes,
      view_transitions: view_transitions,
      position_try: position_try
    }
  end
end
