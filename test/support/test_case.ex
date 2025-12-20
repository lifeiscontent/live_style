defmodule LiveStyle.TestCase do
  @moduledoc """
  Base test case for LiveStyle tests.

  This module provides a consistent test environment with:
  - CSS generation via `generate_css/0`
  - Hash computation helpers
  - Per-process config overrides

  ## Usage

      defmodule MyTest do
        use LiveStyle.TestCase, async: true

        test "example" do
          css = generate_css()
          class = class_name("display", "flex")
          metadata = LiveStyle.get_metadata(MyModule, :root)
        end
      end

  ## Options

  - `:async` - Whether tests can run in parallel (default: true)
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
    :use_css_layers
  ]

  using opts do
    config_opts = Keyword.take(opts, @config_keys)

    quote do
      import LiveStyle.TestCase.Helpers

      setup do
        LiveStyle.TestCase.setup_test(unquote(Macro.escape(config_opts)))
      end
    end
  end

  @doc false
  def setup_test(config_opts) do
    # Apply any config overrides for this test
    for {key, value} <- config_opts do
      LiveStyle.Config.put(key, value)
    end

    # Cleanup on test exit
    ExUnit.Callbacks.on_exit(fn ->
      LiveStyle.Config.reset_all()
    end)

    :ok
  end

  defmodule Helpers do
    @moduledoc """
    Helper functions available in all LiveStyle tests.
    """

    @doc """
    Generates CSS from all registered styles.

    This is a convenience wrapper around `LiveStyle.generate_css/0`.
    """
    def generate_css do
      LiveStyle.generate_css()
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
