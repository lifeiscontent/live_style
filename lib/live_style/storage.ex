defmodule LiveStyle.Storage do
  @moduledoc """
  Storage backend for LiveStyle manifest.

  Provides a unified interface for reading and writing the compile-time manifest,
  with support for different storage backends (File for production, Memory for tests).

  ## Configuration

  Configure the storage backend in your config:

      # Default - file storage with default path
      config :live_style,
        storage: LiveStyle.Storage.File

      # File storage with custom path
      config :live_style,
        storage: {LiveStyle.Storage.File, path: "custom/manifest.etf"}

      # Memory storage (for tests)
      config :live_style,
        storage: LiveStyle.Storage.Memory

  ## Per-Process Backend Override

  For test isolation, you can override the backend on a per-process basis:

      LiveStyle.Storage.set_backend(LiveStyle.Storage.Memory)
      # ... run tests ...
      LiveStyle.Storage.clear_backend()

  This allows tests to run in parallel with `async: true` without conflicts.
  """

  @backend_key :live_style_storage_backend

  @doc """
  Sets the storage backend for the current process.

  This is primarily used for test isolation, allowing each test to use
  an in-memory backend without affecting other tests.

  Can be specified as:
  - A module: `LiveStyle.Storage.Memory`
  - A tuple: `{LiveStyle.Storage.File, path: "custom/path.etf"}`
  """
  def set_backend(backend) do
    Process.put(@backend_key, backend)
    :ok
  end

  @doc """
  Clears the per-process backend override, reverting to the default backend.
  """
  def clear_backend do
    Process.delete(@backend_key)
    :ok
  end

  @doc """
  Returns the appropriate storage backend module and options.

  If a per-process override is set (via `set_backend/1`), that is returned.
  Otherwise, returns the configured backend from application config.

  Returns a tuple of `{module, opts}`.
  """
  def backend do
    case Process.get(@backend_key) do
      nil ->
        LiveStyle.Config.storage()

      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}

      module when is_atom(module) ->
        {module, []}
    end
  end

  @doc """
  Reads the current manifest, ensuring all required keys exist.
  """
  def read do
    {module, opts} = backend()
    manifest = module.read(opts)
    LiveStyle.Manifest.ensure_keys(manifest)
  end

  @doc """
  Writes the manifest.
  """
  def write(manifest) do
    {module, opts} = backend()
    module.write(manifest, opts)
  end

  @doc """
  Updates the manifest with a function.
  """
  def update(fun) do
    {module, opts} = backend()
    module.update(fun, opts)
  end

  @doc """
  Clears the manifest.
  """
  def clear do
    {module, opts} = backend()
    module.clear(opts)
  end

  @doc """
  Checks if the manifest has any styles.
  """
  def has_styles?(manifest) do
    has_vars = map_size(manifest[:var_groups] || %{}) > 0
    has_keyframes = map_size(manifest[:keyframes] || %{}) > 0
    has_rules = map_size(manifest[:rules] || %{}) > 0
    has_properties = map_size(manifest[:properties] || %{}) > 0
    has_position_try = map_size(manifest[:position_try] || %{}) > 0
    has_view_transitions = length(manifest[:view_transition_css] || []) > 0

    has_vars or has_keyframes or has_rules or has_properties or has_position_try or
      has_view_transitions
  end
end
