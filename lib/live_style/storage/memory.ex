defmodule LiveStyle.Storage.Memory do
  @moduledoc """
  In-memory storage backend for testing.

  Uses process dictionary for per-process isolation, enabling tests to run
  in parallel with `async: true` without conflicts or file system access.

  This backend is designed specifically for test isolation - each test process
  gets its own independent storage that is automatically cleaned up when the
  process ends.

  ## Configuration

      config :live_style,
        storage: LiveStyle.Storage.Memory
  """

  @manifest_key :live_style_memory_manifest

  @doc """
  Reads the manifest from the process dictionary.
  Returns an empty manifest with all required keys if none exists.
  """
  def read(_opts \\ []) do
    case Process.get(@manifest_key) do
      nil -> LiveStyle.Manifest.empty()
      manifest -> manifest
    end
  end

  @doc """
  Writes the manifest to the process dictionary.
  """
  def write(manifest, _opts \\ []) do
    Process.put(@manifest_key, manifest)
    :ok
  end

  @doc """
  Updates the manifest atomically.
  Ensures the manifest has all required keys before updating.
  """
  def update(fun, _opts \\ []) do
    manifest = read()
    # Ensure keys exist before passing to the update function
    manifest = LiveStyle.Manifest.ensure_keys(manifest)
    new_manifest = fun.(manifest)
    write(new_manifest)
    :ok
  end

  @doc """
  Clears the manifest.
  """
  def clear(_opts \\ []) do
    Process.put(@manifest_key, LiveStyle.Manifest.empty())
    :ok
  end
end
