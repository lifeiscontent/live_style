defmodule LiveStyle.Storage.File do
  @moduledoc """
  File-based storage backend for production.

  Uses direct file I/O for manifest storage in production environments.
  Uses file locking to prevent race conditions during parallel compilation.

  ## Options

  - `:path` - Path to the manifest file (default: `"_build/live_style_manifest.etf"`)

  ## Configuration

      # Default path
      config :live_style,
        storage: LiveStyle.Storage.File

      # Custom path
      config :live_style,
        storage: {LiveStyle.Storage.File, path: "custom/manifest.etf"}
  """

  @default_path "_build/live_style_manifest.etf"
  @lock_timeout 30_000

  @doc """
  Reads the manifest from file.
  """
  def read(opts \\ []) do
    path = get_path(opts)

    if File.exists?(path) do
      case File.read(path) do
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
    path = get_path(opts)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, :erlang.term_to_binary(manifest))
    :ok
  end

  @doc """
  Updates the manifest atomically using file locking.
  """
  def update(fun, opts \\ []) do
    path = get_path(opts)
    lock_path = path <> ".lock"

    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()

    # Use file-based locking to prevent race conditions
    with_lock(lock_path, fn ->
      manifest = read(opts)
      new_manifest = fun.(manifest)
      write(new_manifest, opts)
    end)

    :ok
  end

  @doc """
  Clears the manifest.
  """
  def clear(opts \\ []) do
    path = get_path(opts)

    if File.exists?(path) do
      File.rm!(path)
    end

    # Write empty manifest to ensure it exists
    write(LiveStyle.Manifest.empty(), opts)
    :ok
  end

  defp get_path(opts) do
    Keyword.get(opts, :path, @default_path)
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
