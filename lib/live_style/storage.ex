defmodule LiveStyle.Storage do
  @moduledoc """
  File-based storage for the LiveStyle manifest.

  Provides simple file-based manifest persistence using atomic file operations
  and file locking for safe concurrent access during compilation.

  ## How It Works

  - Reads/writes go directly to the manifest file
  - Directory-based file locking prevents race conditions during parallel compilation
  - Atomic file operations (write to temp, rename) prevent corruption
  - Per-process state provides test isolation

  ## Storage Location

  Manifests are stored under the Mix build path following the same pattern as
  phoenix-colocated: `_build/{env}/live_style/{app}/manifest.etf`

  This ensures:
  - `mix clean` automatically removes manifests
  - Different environments have separate manifests
  - Multiple apps in an umbrella don't conflict

  ## Configuration

  Override the manifest path in your config (rarely needed):

      config :live_style,
        manifest_path: "custom/path/manifest.etf"
  """
  @process_key :live_style_process_manifest
  @process_usage_key :live_style_process_usage
  @path_key :live_style_path
  @usage_path_key :live_style_usage_path

  # Lock configuration
  @lock_retry_interval 10
  @lock_timeout 30_000
  # Consider a lock stale if older than 5 minutes (crashed process)
  @stale_lock_threshold_seconds 300

  # ===========================================================================
  # Path Management
  # ===========================================================================

  @doc """
  Returns the current manifest path.

  Default: `_build/{env}/live_style/{app}/manifest.etf`
  """
  @spec path() :: String.t()
  def path do
    Process.get(@path_key) ||
      Application.get_env(:live_style, :manifest_path) ||
      default_path("manifest.etf")
  end

  defp default_path(filename) do
    build_path = Mix.Project.build_path()
    app = Mix.Project.config()[:app] || :live_style

    Path.join([build_path, "live_style", to_string(app), filename])
  end

  @doc """
  Sets the manifest path for the current process.
  """
  @spec set_path(String.t()) :: :ok
  def set_path(path) do
    Process.put(@path_key, path)
    :ok
  end

  @doc """
  Clears the per-process path override.
  """
  @spec clear_path() :: :ok
  def clear_path do
    Process.delete(@path_key)
    :ok
  end

  # ===========================================================================
  # Core Operations
  # ===========================================================================

  @doc """
  Reads the manifest from storage.

  Returns an empty manifest if storage is empty or uninitialized.
  """
  @spec read() :: LiveStyle.Manifest.t()
  def read do
    case Process.get(@process_key) do
      nil -> read_from_file()
      manifest -> manifest
    end
  end

  @doc """
  Writes the manifest to storage.
  """
  @spec write(LiveStyle.Manifest.t()) :: :ok
  def write(manifest) do
    if process_active?() do
      Process.put(@process_key, manifest)
    end

    # Always use lock when writing to file for safety against concurrent access
    with_lock(fn -> write_to_file(manifest) end)
    :ok
  end

  @doc """
  Atomically updates the manifest.

  The update function receives the current manifest and returns the new manifest.
  Uses file locking to prevent race conditions during parallel compilation.
  """
  @spec update((LiveStyle.Manifest.t() -> LiveStyle.Manifest.t())) :: :ok
  def update(fun) do
    if process_active?() do
      # Use process-local cache for reads, but still lock file writes
      current = Process.get(@process_key) || LiveStyle.Manifest.empty()
      updated = fun.(current)
      Process.put(@process_key, updated)
      with_lock(fn -> write_to_file(updated) end)
    else
      # Use file locking for concurrent access during compilation
      with_lock(fn ->
        current = read_from_file()
        updated = fun.(current)
        write_to_file(updated)
      end)
    end

    :ok
  end

  @doc """
  Clears the manifest, resetting to empty state.
  """
  @spec clear() :: :ok
  def clear do
    empty = LiveStyle.Manifest.empty()

    if process_active?() do
      Process.put(@process_key, empty)
    end

    # Write empty manifest (overwrites existing file atomically)
    with_lock(fn -> write_to_file(empty) end)
    :ok
  end

  # ===========================================================================
  # Test Isolation
  # ===========================================================================

  @doc """
  Forks the current manifest into this process for test isolation.

  After calling this, all operations use the process-local copy.
  """
  @spec fork() :: :ok
  def fork do
    manifest = read_from_file()
    Process.put(@process_key, manifest)
    :ok
  end

  @doc """
  Returns whether this process has an active local manifest.
  """
  @spec process_active?() :: boolean()
  def process_active?, do: Process.get(@process_key) != nil

  # ===========================================================================
  # Usage Manifest Operations
  # ===========================================================================

  @doc """
  Returns the current usage manifest path.
  """
  @spec usage_path() :: String.t()
  def usage_path do
    Process.get(@usage_path_key) ||
      Application.get_env(:live_style, :usage_path) ||
      default_path("usage.etf")
  end

  @doc """
  Sets the usage manifest path for the current process.
  """
  @spec set_usage_path(String.t()) :: :ok
  def set_usage_path(path) do
    Process.put(@usage_path_key, path)
    :ok
  end

  @doc """
  Clears the per-process usage path override.
  """
  @spec clear_usage_path() :: :ok
  def clear_usage_path do
    Process.delete(@usage_path_key)
    :ok
  end

  @doc """
  Reads the usage manifest from storage.

  Returns an empty usage manifest if storage is empty or uninitialized.
  """
  @spec read_usage() :: LiveStyle.UsageManifest.t()
  def read_usage do
    case Process.get(@process_usage_key) do
      nil -> read_usage_from_file()
      usage -> usage
    end
  end

  @doc """
  Writes the usage manifest to storage.
  """
  @spec write_usage(LiveStyle.UsageManifest.t()) :: :ok
  def write_usage(usage) do
    if usage_process_active?() do
      Process.put(@process_usage_key, usage)
    end

    with_usage_lock(fn -> write_usage_to_file(usage) end)
    :ok
  end

  @doc """
  Atomically updates the usage manifest.

  The update function receives the current usage and returns the new usage.
  Uses file locking to prevent race conditions during parallel compilation.
  """
  @spec update_usage((LiveStyle.UsageManifest.t() -> LiveStyle.UsageManifest.t())) :: :ok
  def update_usage(fun) do
    if usage_process_active?() do
      current = Process.get(@process_usage_key) || LiveStyle.UsageManifest.empty()
      updated = fun.(current)
      Process.put(@process_usage_key, updated)
      with_usage_lock(fn -> write_usage_to_file(updated) end)
    else
      with_usage_lock(fn ->
        current = read_usage_from_file()
        updated = fun.(current)
        write_usage_to_file(updated)
      end)
    end

    :ok
  end

  @doc """
  Clears the usage manifest, resetting to empty state.
  """
  @spec clear_usage() :: :ok
  def clear_usage do
    empty = LiveStyle.UsageManifest.empty()

    if usage_process_active?() do
      Process.put(@process_usage_key, empty)
    end

    with_usage_lock(fn -> write_usage_to_file(empty) end)
    :ok
  end

  @doc """
  Forks the current usage manifest into this process for test isolation.
  """
  @spec fork_usage() :: :ok
  def fork_usage do
    usage = read_usage_from_file()
    Process.put(@process_usage_key, usage)
    :ok
  end

  @doc """
  Returns whether this process has an active local usage manifest.
  """
  @spec usage_process_active?() :: boolean()
  def usage_process_active?, do: Process.get(@process_usage_key) != nil

  # ===========================================================================
  # Module Data Merging
  # ===========================================================================

  @doc """
  Merges all per-module data files into the manifest.

  This is called by the `:live_style` compiler after Elixir compilation completes.
  It can also be called manually (e.g., in test_helper.exs) to ensure the manifest
  is populated before tests run.

  Also merges per-module usage files into the usage manifest (no locking needed
  since this runs after all modules have been compiled).

  Returns the number of modules merged.
  """
  @spec merge_module_data() :: non_neg_integer()
  def merge_module_data do
    alias LiveStyle.Compiler.ModuleData
    alias LiveStyle.Manifest

    module_data = ModuleData.list_all()
    active_modules = MapSet.new(module_data, fn {module, _data} -> module end)

    # Build manifest from per-module data
    manifest =
      Enum.reduce(module_data, Manifest.empty(), fn {module, data}, acc ->
        merge_module_into_manifest(acc, module, data)
      end)

    # Write merged manifest
    write(manifest)

    # Merge per-module usage files into usage manifest
    usage = ModuleData.collect_all_usage()
    write_usage_direct(usage)

    # Clean up outdated module files (modules that no longer use LiveStyle)
    ModuleData.cleanup_outdated(active_modules)

    length(module_data)
  end

  # Write usage directly without locking (called after compilation is complete)
  defp write_usage_direct(usage) do
    file_path = usage_path()
    dir = Path.dirname(file_path)
    File.mkdir_p!(dir)

    temp_path = file_path <> ".tmp"

    try do
      File.write!(temp_path, :erlang.term_to_binary(usage))
      File.rename!(temp_path, file_path)
    rescue
      error ->
        File.rm(temp_path)
        reraise error, __STACKTRACE__
    end
  end

  defp merge_module_into_manifest(manifest, module, data) do
    alias LiveStyle.Manifest

    manifest
    |> merge_vars(module, data)
    |> merge_consts(module, data)
    |> merge_keyframes(module, data)
    |> merge_theme_classes(module, data)
    |> merge_view_transition_classes(module, data)
    |> merge_position_try(module, data)
    |> merge_classes(data)
    |> merge_module_hash(module, data)
  end

  defp merge_vars(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:vars] || [], manifest, fn {name, entry}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_var(acc, key, entry)
    end)
  end

  defp merge_consts(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:consts] || [], manifest, fn {name, value}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_const(acc, key, value)
    end)
  end

  defp merge_keyframes(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:keyframes] || [], manifest, fn {name, entry}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_keyframes(acc, key, entry)
    end)
  end

  defp merge_theme_classes(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:theme_classes] || [], manifest, fn {name, entry}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_theme_class(acc, key, entry)
    end)
  end

  defp merge_view_transition_classes(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:view_transition_classes] || [], manifest, fn {name, entry}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_view_transition_class(acc, key, entry)
    end)
  end

  defp merge_position_try(manifest, module, data) do
    alias LiveStyle.Manifest

    Enum.reduce(data[:position_try] || [], manifest, fn {name, entry}, acc ->
      key = Manifest.key(module, name)
      Manifest.put_position_try(acc, key, entry)
    end)
  end

  defp merge_classes(manifest, data) do
    alias LiveStyle.Manifest

    # Classes are already stored as a map in the module data
    Enum.reduce(data[:classes] || %{}, manifest, fn {key, entry}, acc ->
      Manifest.put_class(acc, key, entry)
    end)
  end

  defp merge_module_hash(manifest, module, data) do
    alias LiveStyle.Manifest

    case data[:module_hash] do
      nil -> manifest
      hash -> Manifest.put_module_hash(manifest, module, hash)
    end
  end

  # ===========================================================================
  # File Operations
  # ===========================================================================

  defp read_from_file do
    file_path = path()

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, binary} ->
          parse_manifest(binary, file_path)

        {:error, reason} ->
          require Logger
          Logger.warning("LiveStyle: Failed to read manifest: #{inspect(reason)}")
          LiveStyle.Manifest.empty()
      end
    else
      LiveStyle.Manifest.empty()
    end
  end

  defp parse_manifest(binary, file_path) do
    manifest = :erlang.binary_to_term(binary)
    LiveStyle.Manifest.ensure_keys(manifest)
  catch
    :error, :badarg ->
      require Logger
      Logger.warning("LiveStyle: Corrupt manifest at #{file_path}, starting fresh")
      LiveStyle.Manifest.empty()
  end

  defp write_to_file(manifest) do
    file_path = path()
    dir = Path.dirname(file_path)
    File.mkdir_p!(dir)

    # Clean up any stale temp files from previous writes
    cleanup_temp_files(dir, Path.basename(file_path))

    # Write to temp file and rename for atomicity
    temp_path = file_path <> ".tmp"

    try do
      File.write!(temp_path, :erlang.term_to_binary(manifest))
      File.rename!(temp_path, file_path)
    rescue
      error ->
        File.rm(temp_path)
        reraise error, __STACKTRACE__
    end
  end

  defp cleanup_temp_files(dir, base_name) do
    prefix = base_name <> ".tmp"

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, prefix))
        |> Enum.each(fn file -> File.rm(Path.join(dir, file)) end)

      {:error, _} ->
        :ok
    end
  end

  # ===========================================================================
  # File Locking (for concurrent compilation)
  # ===========================================================================

  defp lock_path, do: path() <> ".lock"

  defp with_lock(fun) when is_function(fun, 0) do
    lock = lock_path()
    # Ensure directory exists
    lock |> Path.dirname() |> File.mkdir_p!()
    # Clean stale locks before attempting to acquire
    maybe_clean_stale_lock(lock)
    acquire_lock(lock, @lock_timeout)

    try do
      fun.()
    after
      release_lock(lock)
    end
  end

  defp maybe_clean_stale_lock(lock) do
    case File.stat(lock) do
      {:ok, %{mtime: mtime}} ->
        age_seconds = System.os_time(:second) - to_unix_time(mtime)

        if age_seconds > @stale_lock_threshold_seconds do
          File.rm_rf(lock)
        end

      {:error, _} ->
        :ok
    end
  end

  defp to_unix_time({{year, month, day}, {hour, min, sec}}) do
    :calendar.datetime_to_gregorian_seconds({{year, month, day}, {hour, min, sec}}) -
      :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
  end

  defp acquire_lock(lock, timeout) when timeout > 0 do
    case File.mkdir(lock) do
      :ok ->
        :ok

      {:error, :eexist} ->
        Process.sleep(@lock_retry_interval)
        acquire_lock(lock, timeout - @lock_retry_interval)

      {:error, reason} ->
        raise RuntimeError,
          message: "Failed to acquire lock at #{lock}: #{inspect(reason)}"
    end
  end

  defp acquire_lock(lock, _timeout) do
    raise RuntimeError,
      message:
        "Timeout acquiring lock at #{lock}. " <>
          "Another process may be holding the lock. " <>
          "Try deleting #{lock} if no other process is running."
  end

  defp release_lock(lock), do: File.rm_rf(lock)

  # ===========================================================================
  # Usage File Operations
  # ===========================================================================

  defp read_usage_from_file do
    file_path = usage_path()

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, binary} ->
          parse_usage(binary, file_path)

        {:error, reason} ->
          require Logger
          Logger.warning("LiveStyle: Failed to read usage manifest: #{inspect(reason)}")
          LiveStyle.UsageManifest.empty()
      end
    else
      LiveStyle.UsageManifest.empty()
    end
  end

  defp parse_usage(binary, file_path) do
    :erlang.binary_to_term(binary)
  catch
    :error, :badarg ->
      require Logger
      Logger.warning("LiveStyle: Corrupt usage manifest at #{file_path}, starting fresh")
      LiveStyle.UsageManifest.empty()
  end

  defp write_usage_to_file(usage) do
    file_path = usage_path()
    dir = Path.dirname(file_path)
    File.mkdir_p!(dir)

    # Clean up any stale temp files from previous writes
    cleanup_temp_files(dir, Path.basename(file_path))

    # Write to temp file and rename for atomicity
    temp_path = file_path <> ".tmp"

    try do
      File.write!(temp_path, :erlang.term_to_binary(usage))
      File.rename!(temp_path, file_path)
    rescue
      error ->
        File.rm(temp_path)
        reraise error, __STACKTRACE__
    end
  end

  # ===========================================================================
  # Usage File Locking
  # ===========================================================================

  defp usage_lock_path, do: usage_path() <> ".lock"

  defp with_usage_lock(fun) when is_function(fun, 0) do
    lock = usage_lock_path()
    lock |> Path.dirname() |> File.mkdir_p!()
    maybe_clean_stale_lock(lock)
    acquire_lock(lock, @lock_timeout)

    try do
      fun.()
    after
      release_lock(lock)
    end
  end
end
