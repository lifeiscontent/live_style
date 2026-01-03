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

  ## Configuration

  Configure the manifest path in your config:

      config :live_style,
        manifest_path: "priv/live_style_manifest.etf"

  The default path is `"priv/live_style_manifest.etf"`.
  """

  @default_path "priv/live_style_manifest.etf"
  @process_key :live_style_process_manifest
  @path_key :live_style_path

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
  """
  @spec path() :: String.t()
  def path do
    Process.get(@path_key) ||
      Application.get_env(:live_style, :manifest_path, @default_path)
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

    write_to_file(manifest)
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
      current = Process.get(@process_key) || LiveStyle.Manifest.empty()
      updated = fun.(current)
      Process.put(@process_key, updated)
      write_to_file(updated)
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

    file_path = path()
    if File.exists?(file_path), do: File.rm!(file_path)

    write_to_file(empty)
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
    file_path |> Path.dirname() |> File.mkdir_p!()

    # Write to temp file and rename for atomicity
    temp_path = file_path <> ".tmp.#{:erlang.unique_integer([:positive])}"

    try do
      File.write!(temp_path, :erlang.term_to_binary(manifest))
      File.rename!(temp_path, file_path)
    rescue
      error ->
        File.rm(temp_path)
        reraise error, __STACKTRACE__
    end
  end

  # ===========================================================================
  # File Locking (for concurrent compilation)
  # ===========================================================================

  defp lock_path, do: path() <> ".lock"

  defp with_lock(fun) when is_function(fun, 0) do
    lock = lock_path()
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
end
