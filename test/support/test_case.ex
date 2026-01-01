defmodule LiveStyle.TestCase do
  @moduledoc """
  Base test case for LiveStyle tests.

  This module provides a consistent test environment with:
  - Isolated manifest per test (for async test safety)
  - Per-process config overrides

  ## Usage

      defmodule MyTest do
        use LiveStyle.TestCase

        test "example" do
          css = LiveStyle.generate_css()
        end
      end

  ## Options

  - `:async` - Whether tests can run in parallel (default: `true`)
  - `:shorthand_behavior` - Shorthand expansion behavior (atom, module, or `{module, opts}` tuple)
  - `:class_name_prefix` - Prefix for generated class names
  - `:debug_class_names` - Include property names in class names
  - `:font_size_px_to_rem` - Convert font-size px values to rem
  - `:font_size_root_px` - Root font size for px to rem conversion
  - `:use_css_layers` - Wrap CSS output in @layer blocks
  """

  use ExUnit.CaseTemplate

  @config_keys [
    :shorthand_behavior,
    :class_name_prefix,
    :debug_class_names,
    :font_size_px_to_rem,
    :font_size_root_px,
    :use_css_layers,
    :prefix_css,
    :vendor_prefix_level
  ]

  using opts do
    config_opts = Keyword.take(opts, @config_keys)
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)

      # Store config options in module attribute for runtime access
      # This allows functions to be preserved properly
      @live_style_config_opts unquote(config_opts)

      setup do
        LiveStyle.TestCase.setup_test(@live_style_config_opts)
      end
    end
  end

  @doc false
  def setup_test(config_opts) do
    # Generate a unique manifest path for this test process
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    manifest_path = Path.join(System.tmp_dir!(), "live_style_test_#{unique_id}.etf")

    # Read the shared manifest (compiled test modules)
    manifest = LiveStyle.Storage.read()

    # Set this test's unique manifest path
    LiveStyle.Storage.set_path(manifest_path)

    # Write the manifest to the test's unique file
    LiveStyle.Storage.write(manifest)

    # Apply any config overrides for this test
    for {key, value} <- config_opts do
      LiveStyle.Config.put(key, value)
    end

    # Cleanup on test exit
    ExUnit.Callbacks.on_exit(fn ->
      File.rm(manifest_path)
      LiveStyle.Storage.clear_path()
      LiveStyle.Config.reset_all()
    end)

    :ok
  end
end
