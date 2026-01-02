defmodule LiveStyle.TestCase do
  @moduledoc """
  Base test case for LiveStyle tests.

  This module provides a consistent test environment with:
  - Isolated manifest per test (for async test safety)

  ## Usage

      defmodule MyTest do
        use LiveStyle.TestCase

        test "example" do
          css = LiveStyle.Compiler.generate_css()
        end
      end

  ## How Test Isolation Works

  Each test process receives its own copy of the manifest via `ProcessState.fork/0`.
  This ensures:

  1. Tests can modify the manifest without affecting other tests
  2. The shared ETS cache remains pristine for module compilation
  3. No race conditions between test execution and test file loading

  ## Options

  - `:async` - Whether tests can run in parallel (default: `true`)

  ## Configuration

  All LiveStyle configuration is compile-time only (like StyleX's Babel plugin config).
  Set configuration in config/config.exs or config/test.exs:

      config :live_style,
        class_name_prefix: "x",
        use_css_layers: false,
        debug_class_names: true
  """

  use ExUnit.CaseTemplate

  alias LiveStyle.Storage
  alias LiveStyle.Storage.IO, as: StorageIO
  alias LiveStyle.Storage.ProcessState

  using opts do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)

      setup do
        LiveStyle.TestCase.setup_test()
      end
    end
  end

  @doc false
  def setup_test do
    # Fork the shared manifest into this process
    # This creates a per-process copy that won't affect the shared cache
    ProcessState.fork()

    # Generate a unique manifest path for this test process
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    manifest_path = Path.join(System.tmp_dir!(), "live_style_test_#{unique_id}.etf")

    # Set this test's unique manifest path
    Storage.set_path(manifest_path)

    # Write the forked manifest to the test's unique file
    # This ensures file-based reads work correctly
    manifest = ProcessState.get()
    File.mkdir_p!(Path.dirname(manifest_path))
    StorageIO.write(manifest, manifest_path)

    # Cleanup on test exit
    ExUnit.Callbacks.on_exit(fn ->
      File.rm(manifest_path)
      ProcessState.delete()
      Storage.clear_path()
    end)

    :ok
  end
end
