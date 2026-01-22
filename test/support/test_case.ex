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

  Each test process receives its own copy of the manifest via `Storage.fork/0`.
  This ensures:

  1. Tests can modify the manifest without affecting other tests
  2. The shared manifest file remains pristine for module compilation
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
    # Fork the shared manifest and usage into this process BEFORE changing paths
    # This ensures we get the compile-time recorded data
    Storage.fork()
    Storage.fork_usage()

    # Generate unique manifest paths for this test process
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    manifest_path = Path.join(System.tmp_dir!(), "live_style_test_#{unique_id}.etf")
    usage_path = Path.join(System.tmp_dir!(), "live_style_usage_test_#{unique_id}.etf")

    # Set this test's unique manifest and usage paths
    Storage.set_path(manifest_path)
    Storage.set_usage_path(usage_path)

    # Write the forked manifest to the test's unique file
    manifest = Storage.read()
    Storage.write(manifest)

    # Mark all classes as used for testing (like StyleX's treeshakeCompensation)
    # This ensures CSS is generated for all defined classes in tests
    usage = Storage.read_usage()
    usage = LiveStyle.UsageManifest.mark_all_used(usage, manifest)
    Storage.write_usage(usage)

    # Cleanup on test exit
    ExUnit.Callbacks.on_exit(fn ->
      File.rm(manifest_path)
      File.rm(usage_path)
      Storage.clear_path()
      Storage.clear_usage_path()
    end)

    :ok
  end
end
