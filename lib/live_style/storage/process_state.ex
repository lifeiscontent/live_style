defmodule LiveStyle.Storage.ProcessState do
  @moduledoc """
  Per-process manifest storage for test isolation.

  During tests, each test process maintains its own copy of the manifest in the
  process dictionary. This ensures:

  1. Tests can modify manifests without affecting each other
  2. The shared ETS cache remains pristine for concurrent module compilation
  3. No race conditions between test execution and module loading

  ## Usage

  This module is used internally by `LiveStyle.Storage.FileAdapter`. You typically
  don't need to use it directly.

  ## How It Works

  When a test starts:
  1. `fork/0` copies the shared manifest into the process dictionary
  2. All subsequent reads/writes use the process-local copy
  3. The shared ETS cache is untouched
  4. `cleanup/0` removes the process-local copy on test exit
  """

  alias LiveStyle.Manifest
  alias LiveStyle.Storage.Cache
  alias LiveStyle.Storage.IO, as: StorageIO
  alias LiveStyle.Storage.Path, as: StoragePath

  @key :live_style_process_manifest

  @doc """
  Returns whether this process has an active local manifest.

  When true, storage operations use the per-process manifest.
  When false, storage operations use the shared ETS cache.
  """
  @spec active?() :: boolean()
  def active?, do: get() != nil

  @doc """
  Gets the process-local manifest, or nil if not active.
  """
  @spec get() :: LiveStyle.Manifest.t() | nil
  def get, do: Process.get(@key)

  @doc """
  Sets the process-local manifest.

  After this call, `active?/0` returns true and all storage operations
  use this process-local manifest instead of the shared cache.
  """
  @spec put(LiveStyle.Manifest.t()) :: :ok
  def put(manifest) do
    Process.put(@key, manifest)
    :ok
  end

  @doc """
  Removes the process-local manifest.

  After this call, `active?/0` returns false and storage operations
  resume using the shared ETS cache.
  """
  @spec delete() :: :ok
  def delete do
    Process.delete(@key)
    :ok
  end

  @doc """
  Forks the current shared manifest into this process.

  This creates a process-local copy that can be modified without
  affecting the shared state. Used by test setup.
  """
  @spec fork() :: :ok
  def fork do
    # Read from the shared cache (bypassing process state check)
    Cache.init()

    manifest =
      if Cache.initialized?() do
        Cache.get_manifest() || Manifest.empty()
      else
        # If cache not initialized, try loading from file
        file_path = StoragePath.path()

        if File.exists?(file_path) do
          StorageIO.read(file_path)
        else
          Manifest.empty()
        end
      end

    put(manifest)
  end
end
