defmodule LiveStyle.Storage.FileAdapter do
  @moduledoc """
  File-based storage adapter for LiveStyle.

  This adapter uses a two-tier storage architecture:

  1. **Shared ETS cache** - Primary storage during module compilation. Lock-free
     for parallel access, shared across all processes on the node.

  2. **Per-process state** - Isolated storage for test execution. Each test
     process can have its own manifest copy that doesn't affect the shared cache.

  ## How It Works

  During normal compilation:
  - All reads/writes go through the shared ETS cache
  - No file I/O until `persist/0` is called at the end of compilation
  - Parallel module compilation is lock-free

  During test execution:
  - Each test forks the shared manifest into per-process state
  - Reads/writes use the per-process copy
  - The shared ETS cache remains untouched
  - No interference between concurrent tests or module compilation

  ## Configuration

  Configure the manifest path in your config:

      config :live_style,
        manifest_path: "priv/live_style_manifest.etf"

  The default path is `"priv/live_style_manifest.etf"`.

  ## Per-Process Path Override

  For test isolation, you can override the manifest path on a per-process basis:

      LiveStyle.Storage.set_path("/tmp/test_manifest.etf")
      # ... run tests ...
      LiveStyle.Storage.clear_path()
  """

  @behaviour LiveStyle.Storage.Adapter

  alias LiveStyle.Storage.{Cache, IO, Lock, ProcessState}
  alias LiveStyle.Storage.Path, as: StoragePath

  @default_lock_timeout 30_000

  @doc """
  Returns the lock timeout in milliseconds.

  Configurable via:

      config :live_style, lock_timeout: 60_000

  Defaults to 30 seconds.
  """
  def lock_timeout do
    Application.get_env(:live_style, :lock_timeout, @default_lock_timeout)
  end

  @doc """
  Sets the manifest path for the current process.
  """
  defdelegate set_path(path), to: StoragePath

  @doc """
  Clears the per-process path override.
  """
  defdelegate clear_path(), to: StoragePath

  @doc """
  Returns the current manifest path.
  """
  defdelegate path(), to: StoragePath

  @impl LiveStyle.Storage.Adapter
  def read do
    # Check for per-process manifest first (test isolation)
    case ProcessState.get() do
      nil ->
        # No per-process state, use shared cache
        ensure_cache_initialized()
        Cache.get_manifest() || LiveStyle.Manifest.empty()

      manifest ->
        # Use per-process manifest (test mode)
        manifest
    end
  end

  @impl LiveStyle.Storage.Adapter
  def write(manifest) do
    if ProcessState.active?() do
      # Test mode: update per-process state only, don't touch shared cache
      ProcessState.put(manifest)

      # Also write to per-process file path
      file_path = path()
      file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

      with_lock(file_path, fn ->
        IO.write(manifest, file_path)
      end)
    else
      # Normal mode: update shared cache and write to file
      Cache.invalidate()
      Cache.populate_from_manifest(manifest)

      file_path = path()
      file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

      with_lock(file_path, fn ->
        IO.write(manifest, file_path)
      end)
    end

    :ok
  end

  @impl LiveStyle.Storage.Adapter
  def update(fun) do
    if ProcessState.active?() do
      # Test mode: update per-process state only
      current = ProcessState.get() || LiveStyle.Manifest.empty()
      updated = fun.(current)
      ProcessState.put(updated)
    else
      # Normal mode: update cache and persist to file
      # During compilation, ETS table may not survive between compiler phases,
      # so we persist to file immediately to ensure data is not lost
      ensure_cache_initialized()
      current = Cache.get_manifest() || LiveStyle.Manifest.empty()
      updated = fun.(current)
      sync_to_cache(current, updated)

      # Persist to file immediately during compilation
      # This ensures data survives if the ETS table is destroyed
      persist()
    end

    :ok
  end

  @impl LiveStyle.Storage.Adapter
  def clear do
    if ProcessState.active?() do
      # Test mode: clear per-process state and file
      ProcessState.put(LiveStyle.Manifest.empty())

      file_path = path()

      if File.exists?(file_path) do
        File.rm!(file_path)
      end

      # Write empty manifest to file
      write(LiveStyle.Manifest.empty())
    else
      # Normal mode: clear shared cache and file
      file_path = path()

      if File.exists?(file_path) do
        File.rm!(file_path)
      end

      Cache.invalidate()
      Cache.populate_from_manifest(LiveStyle.Manifest.empty())

      # Write empty manifest to file
      with_lock(file_path, fn ->
        file_path |> Elixir.Path.dirname() |> File.mkdir_p!()
        IO.write(LiveStyle.Manifest.empty(), file_path)
      end)
    end

    :ok
  end

  @doc """
  Persists the current ETS cache to disk.

  Call this at the end of compilation to save all accumulated changes.
  This only persists the shared cache, not per-process state.
  """
  def persist do
    case Cache.get_manifest() do
      nil ->
        :ok

      manifest ->
        file_path = path()
        file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

        with_lock(file_path, fn ->
          IO.write(manifest, file_path)
        end)

        :ok
    end
  end

  # Ensure cache is initialized from file
  defp ensure_cache_initialized do
    unless Cache.initialized?() do
      load_from_file()
    end
  end

  # Load manifest from file into ETS cache
  defp load_from_file do
    file_path = path()

    manifest =
      if File.exists?(file_path) do
        with_lock(file_path, fn ->
          IO.read(file_path)
        end)
      else
        LiveStyle.Manifest.empty()
      end

    Cache.populate_from_manifest(manifest)
    manifest
  end

  # Sync changed entries from updated manifest to cache
  # Collections are sorted lists of {key, entry} tuples
  defp sync_to_cache(old, new) do
    sync_collection(old.classes, new.classes, &Cache.put_class/2)
    sync_collection(old.vars, new.vars, &Cache.put_var/2)
    sync_collection(old.theme_classes, new.theme_classes, &Cache.put_theme_class/2)
    sync_collection(old.consts, new.consts, &Cache.put_const/2)
    sync_collection(old.keyframes, new.keyframes, &Cache.put_keyframes/2)

    sync_collection(
      old.view_transition_classes,
      new.view_transition_classes,
      &Cache.put_view_transition_class/2
    )

    sync_collection(old.position_try, new.position_try, &Cache.put_position_try/2)
    :ok
  end

  defp sync_collection(old_entries, new_entries, put_fn) do
    old_map = list_to_map(old_entries || [])

    for {key, entry} <- new_entries || [] do
      if Map.get(old_map, key) != entry do
        put_fn.(key, entry)
      end
    end
  end

  # Convert sorted list to map for efficient lookups during sync
  defp list_to_map(list), do: Map.new(list)

  defp with_lock(file_path, fun) do
    lock_path = file_path <> ".lock"
    Lock.with_lock(lock_path, lock_timeout(), fun)
  end
end
