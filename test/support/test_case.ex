defmodule LiveStyle.TestCase do
  @moduledoc """
  Base test case for LiveStyle tests.

  This module provides a consistent test environment with:
  - In-memory storage backend (default) for test isolation
  - Access to the manifest via `get_manifest/0`
  - CSS generation via `generate_css/0`
  - Hash computation helpers
  - Per-process config overrides

  ## Usage

      defmodule MyTest do
        use LiveStyle.TestCase, async: true

        test "example" do
          manifest = get_manifest()
          css = generate_css()
          class = class_name("display", "flex")
        end
      end

  ## Options

  - `:async` - Whether tests can run in parallel (default: true)
  - `:storage` - Storage backend (default: `LiveStyle.Storage.Memory`)
  - `:shorthand_strategy` - Shorthand expansion strategy (atom, module, or `{module, opts}` tuple)
  - `:class_name_prefix` - Prefix for generated class names
  - `:debug_class_names` - Include property names in class names
  - `:font_size_px_to_rem` - Convert font-size px values to rem
  - `:font_size_root_px` - Root font size for px to rem conversion
  - `:use_css_layers` - Wrap CSS output in @layer blocks

  ## Example with File Storage

      defmodule FileStorageTest do
        # Must be async: false when using file storage
        use LiveStyle.TestCase, async: false, storage: LiveStyle.Storage.File

        # Tests that specifically need to test file storage behavior
      end
  """

  use ExUnit.CaseTemplate

  @config_keys [
    :shorthand_strategy,
    :class_name_prefix,
    :debug_class_names,
    :font_size_px_to_rem,
    :font_size_root_px,
    :use_css_layers
  ]

  @manifest_key {__MODULE__, :compiled_manifest}

  using opts do
    config_opts = Keyword.take(opts, @config_keys)
    storage = Keyword.get(opts, :storage, LiveStyle.Storage.Memory)

    quote do
      import LiveStyle.TestCase.Helpers

      setup do
        LiveStyle.TestCase.setup_test(
          unquote(Macro.escape(config_opts)),
          unquote(Macro.escape(storage))
        )
      end
    end
  end

  @doc """
  Returns the manifest that was compiled when the test suite started.

  This is cached in :persistent_term for efficient concurrent access.
  The first call reads from file storage and caches it.
  """
  def compiled_manifest do
    # Try to get from cache first (fast path)
    case :persistent_term.get(@manifest_key, :not_found) do
      :not_found ->
        # Need to initialize - use a global lock to prevent race conditions
        init_compiled_manifest()

      manifest ->
        manifest
    end
  end

  defp init_compiled_manifest do
    # Use :global.trans to ensure only one process initializes the cache
    :global.trans({@manifest_key, self()}, fn ->
      # Double-check inside the lock
      case :persistent_term.get(@manifest_key, :not_found) do
        :not_found ->
          manifest = LiveStyle.Storage.File.read()
          :persistent_term.put(@manifest_key, manifest)
          manifest

        manifest ->
          manifest
      end
    end)
  end

  @doc false
  def setup_test(config_opts, storage) do
    # Set the storage backend for this test process
    LiveStyle.Storage.set_backend(storage)

    # If using memory backend, populate it with the compiled manifest
    storage_module =
      case storage do
        {module, _opts} -> module
        module -> module
      end

    if storage_module == LiveStyle.Storage.Memory do
      LiveStyle.Storage.Memory.write(compiled_manifest())
    end

    # Apply any config overrides for this test
    for {key, value} <- config_opts do
      LiveStyle.Config.put(key, value)
    end

    # Cleanup on test exit
    ExUnit.Callbacks.on_exit(fn ->
      LiveStyle.Storage.clear_backend()
      LiveStyle.Config.reset_all()
    end)

    :ok
  end

  defmodule Helpers do
    @moduledoc """
    Helper functions available in all LiveStyle tests.
    """

    @doc """
    Gets the current manifest from storage.
    """
    def get_manifest do
      LiveStyle.Storage.read()
    end

    @doc """
    Generates CSS from the current manifest.
    """
    def generate_css do
      LiveStyle.CSS.generate(get_manifest())
    end

    @doc """
    Computes the expected class name for a CSS property-value pair.

    ## Examples

        iex> class_name("display", "flex")
        "x78zum5"

        iex> class_name("color", "blue", ":hover")
        "x..."
    """
    def class_name(property, value, selector_suffix \\ nil, at_rule \\ nil) do
      pseudos =
        case selector_suffix do
          nil -> []
          "" -> []
          str -> [str]
        end

      at_rules =
        case at_rule do
          nil -> []
          "" -> []
          str -> [str]
        end

      LiveStyle.Hash.class_name(property, value, pseudos, at_rules)
    end

    @doc """
    Computes the expected CSS variable name for a module, namespace, and name.
    """
    def var_name(module, namespace, name) do
      LiveStyle.Hash.var_name(module, namespace, name)
    end

    @doc """
    Computes the expected keyframes animation name.
    """
    def keyframes_name(frames) do
      LiveStyle.Hash.keyframes_name(frames)
    end

    @doc """
    Computes the expected var group hash for a namespace.
    """
    def var_group_hash(namespace) do
      LiveStyle.Hash.theme_name(namespace)
    end
  end
end
