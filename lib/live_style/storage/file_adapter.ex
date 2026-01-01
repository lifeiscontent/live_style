defmodule LiveStyle.Storage.FileAdapter do
  @moduledoc """
  File-based storage adapter for LiveStyle.

  This is the default adapter that persists the manifest to disk using Erlang
  Term Format (ETF). It includes file locking for safe concurrent access.

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

  @impl LiveStyle.Storage.Adapter
  def read do
    file_path = path()

    if File.exists?(file_path) do
      with_lock(file_path, fn ->
        IO.read(file_path)
      end)
    else
      LiveStyle.Manifest.empty()
    end
  end

  @impl LiveStyle.Storage.Adapter
  def write(manifest) do
    file_path = path()
    file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

    with_lock(file_path, fn ->
      IO.write(manifest, file_path)
    end)

    :ok
  end

  @impl LiveStyle.Storage.Adapter
  def update(fun) do
    file_path = path()
    file_path |> Elixir.Path.dirname() |> File.mkdir_p!()

    with_lock(file_path, fn ->
      manifest = IO.read(file_path)
      new_manifest = fun.(manifest)
      unless new_manifest === manifest, do: IO.write(new_manifest, file_path)
    end)

    :ok
  end

  @impl LiveStyle.Storage.Adapter
  def clear do
    file_path = path()

    if File.exists?(file_path) do
      File.rm!(file_path)
    end

    write(LiveStyle.Manifest.empty())
    :ok
  end

  defp with_lock(file_path, fun) do
    lock_path = file_path <> ".lock"
    Lock.with_lock(lock_path, lock_timeout(), fun)
  end
end
