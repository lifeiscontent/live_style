defmodule LiveStyle.Storage do
  @moduledoc """
  Storage facade for the LiveStyle manifest.

  This module delegates to the configured storage adapter, defaulting to
  `LiveStyle.Storage.FileAdapter` for file-based persistence.

  ## Configuration

  Configure a custom storage adapter:

      config :live_style,
        storage_adapter: MyAppWeb.CustomStorageAdapter

  The adapter must implement the `LiveStyle.Storage.Adapter` behaviour.

  ## Default Adapter

  The default `LiveStyle.Storage.FileAdapter` supports:

  - File-based persistence using Erlang Term Format (ETF)
  - File locking for safe concurrent access
  - Per-process path overrides for test isolation

  See `LiveStyle.Storage.FileAdapter` for configuration options.
  """

  alias LiveStyle.Storage.FileAdapter

  @doc """
  Returns the configured storage adapter module.

  Defaults to `LiveStyle.Storage.FileAdapter`.
  """
  @spec adapter() :: module()
  def adapter do
    Application.get_env(:live_style, :storage_adapter, FileAdapter)
  end

  # Delegate path management to FileAdapter (file-specific operations)

  @doc """
  Sets the manifest path for the current process.

  Only applicable when using `LiveStyle.Storage.FileAdapter`.
  """
  defdelegate set_path(path), to: FileAdapter

  @doc """
  Clears the per-process path override.

  Only applicable when using `LiveStyle.Storage.FileAdapter`.
  """
  defdelegate clear_path(), to: FileAdapter

  @doc """
  Returns the current manifest path.

  Only applicable when using `LiveStyle.Storage.FileAdapter`.
  """
  defdelegate path(), to: FileAdapter

  @doc """
  Returns the lock timeout in milliseconds.

  Only applicable when using `LiveStyle.Storage.FileAdapter`.
  """
  defdelegate lock_timeout(), to: FileAdapter

  @doc """
  Reads the manifest from storage.

  Returns an empty manifest if storage is empty or uninitialized.
  """
  @spec read() :: LiveStyle.Manifest.t()
  def read do
    adapter().read()
  end

  @doc """
  Writes the manifest to storage.
  """
  @spec write(LiveStyle.Manifest.t()) :: :ok
  def write(manifest) do
    adapter().write(manifest)
  end

  @doc """
  Atomically updates the manifest.

  The update function receives the current manifest and returns the new manifest.
  If the returned manifest is identical (same reference), the write may be skipped.
  """
  @spec update((LiveStyle.Manifest.t() -> LiveStyle.Manifest.t())) :: :ok
  def update(fun) do
    adapter().update(fun)
  end

  @doc """
  Clears the manifest, resetting to empty state.
  """
  @spec clear() :: :ok
  def clear do
    adapter().clear()
  end
end
