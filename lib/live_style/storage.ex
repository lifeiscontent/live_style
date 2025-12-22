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

  alias LiveStyle.Storage.{IO, Lock}
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

  @doc """
  Reads the manifest from file.

  Returns an empty manifest if the file doesn't exist or can't be parsed.
  Uses file locking to prevent reading partially-written files.
  """
  def read(opts \\ []) do
    file_path = Keyword.get(opts, :path, path())

    if File.exists?(file_path) do
      with_lock(file_path, fn ->
        IO.read(file_path)
      end)
    else
      LiveStyle.Manifest.empty()
    end
  end

  @doc """
  Writes the manifest to file.

  Uses file locking to prevent concurrent writes from corrupting the file.
  """
  def write(manifest, opts \\ []) do
    file_path = Keyword.get(opts, :path, path())
    file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

    with_lock(file_path, fn ->
      IO.write(manifest, file_path)
    end)

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
    file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

    with_lock(file_path, fn ->
      manifest = IO.read(file_path)
      new_manifest = fun.(manifest)
      unless new_manifest === manifest, do: IO.write(new_manifest, file_path)
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

    write(LiveStyle.Manifest.empty(), path: file_path)
    :ok
  end

  defp with_lock(file_path, fun) do
    lock_path = file_path <> ".lock"
    Lock.with_lock(lock_path, lock_timeout(), fun)
  end
end
