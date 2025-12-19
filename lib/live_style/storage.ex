defmodule LiveStyle.Storage do
  @moduledoc """
  File-based storage for the LiveStyle manifest.

  The manifest stores all CSS rules, variables, keyframes, and other definitions
  that are collected at compile time and used to generate CSS.

  ## Configuration

  Configure the manifest path in your config:

      config :live_style,
        manifest_path: "_build/live_style_manifest.etf"

  The default path is `"_build/live_style_manifest.etf"`.

  ## Per-Process Path Override

  For test isolation, you can override the manifest path on a per-process basis:

      LiveStyle.Storage.set_path("/tmp/test_manifest.etf")
      # ... run tests ...
      LiveStyle.Storage.clear_path()

  This allows tests to run in parallel with `async: true` without conflicts.
  """

  @default_path "_build/live_style_manifest.etf"
  @lock_timeout 30_000
  @path_key :live_style_manifest_path

  @doc """
  Sets the manifest path for the current process.

  This is primarily used for test isolation, allowing each test to use
  a separate manifest file without affecting other tests.
  """
  def set_path(path) when is_binary(path) do
    Process.put(@path_key, path)
    :ok
  end

  @doc """
  Clears the per-process path override, reverting to the default path.
  """
  def clear_path do
    Process.delete(@path_key)
    :ok
  end

  @doc """
  Returns the current manifest path.

  If a per-process override is set (via `set_path/1`), that is returned.
  Otherwise, returns the configured path from application config, or the default.
  """
  def path do
    Process.get(@path_key) ||
      Application.get_env(:live_style, :manifest_path, @default_path)
  end

  @doc """
  Reads the manifest from file.
  """
  def read(opts \\ []) do
    file_path = Keyword.get(opts, :path, path())

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, binary} ->
          try do
            manifest = :erlang.binary_to_term(binary)
            LiveStyle.Manifest.ensure_keys(manifest)
          rescue
            _ -> LiveStyle.Manifest.empty()
          end

        _ ->
          LiveStyle.Manifest.empty()
      end
    else
      LiveStyle.Manifest.empty()
    end
  end

  @doc """
  Writes the manifest to file.
  """
  def write(manifest, opts \\ []) do
    file_path = Keyword.get(opts, :path, path())
    file_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(file_path, :erlang.term_to_binary(manifest))
    :ok
  end

  @doc """
  Updates the manifest atomically using file locking.

  The update function receives the current manifest and should return the
  new manifest. If the returned manifest is identical to the input (same
  reference), the write is skipped to avoid unnecessary I/O.
  """
  def update(fun, opts \\ []) do
    file_path = Keyword.get(opts, :path, path())
    lock_path = file_path <> ".lock"

    # Ensure directory exists
    file_path |> Path.dirname() |> File.mkdir_p!()

    # Use file-based locking to prevent race conditions
    with_lock(lock_path, fn ->
      manifest = read(path: file_path)
      new_manifest = fun.(manifest)

      # Skip write if manifest unchanged (same reference returned)
      unless new_manifest === manifest do
        write(new_manifest, path: file_path)
      end
    end)

    :ok
  end

  @doc """
  Clears the manifest.
  """
  def clear(opts \\ []) do
    file_path = Keyword.get(opts, :path, path())

    if File.exists?(file_path) do
      File.rm!(file_path)
    end

    # Write empty manifest to ensure it exists
    write(LiveStyle.Manifest.empty(), path: file_path)
    :ok
  end

  @doc """
  Checks if the manifest has any styles.
  """
  def has_styles?(manifest) do
    has_map_entries?(manifest, :var_groups) or
      has_map_entries?(manifest, :keyframes) or
      has_map_entries?(manifest, :classes) or
      has_map_entries?(manifest, :properties) or
      has_map_entries?(manifest, :position_try) or
      has_list_entries?(manifest, :view_transition_css)
  end

  defp has_map_entries?(manifest, key) do
    map_size(manifest[key] || %{}) > 0
  end

  defp has_list_entries?(manifest, key) do
    not Enum.empty?(manifest[key] || [])
  end

  # Simple file-based locking using mkdir (atomic on most filesystems)
  defp with_lock(lock_path, fun) do
    acquire_lock(lock_path, @lock_timeout)

    try do
      fun.()
    after
      release_lock(lock_path)
    end
  end

  defp acquire_lock(lock_path, timeout) when timeout > 0 do
    case File.mkdir(lock_path) do
      :ok ->
        :ok

      {:error, :eexist} ->
        # Lock exists, wait and retry
        Process.sleep(10)
        acquire_lock(lock_path, timeout - 10)

      {:error, reason} ->
        raise "Failed to acquire lock at #{lock_path}: #{inspect(reason)}"
    end
  end

  defp acquire_lock(lock_path, _timeout) do
    # Timeout reached - force remove stale lock and try once more
    File.rm_rf(lock_path)
    File.mkdir!(lock_path)
  end

  defp release_lock(lock_path) do
    File.rm_rf(lock_path)
  end
end
