defmodule LiveStyle.Compiler do
  @moduledoc """
  Compiler utilities for LiveStyle.

  This module provides functions for working with compiled LiveStyle output,
  including CSS generation and class resolution.

  ## CSS Generation

      css = LiveStyle.Compiler.generate_css()
      # => "@layer live_style { .x1234{display:flex} ... }"

  ## Class Resolution (useful for testing)

      # Get attrs for a module's styles
      attrs = LiveStyle.Compiler.get_css(MyComponent, [:button])

      # Get class string only
      class = LiveStyle.Compiler.get_css_class(MyComponent, [:button])
  """

  alias LiveStyle.Compiler.CSS, as: CSSCompiler

  @doc """
  Gets CSS attrs from a module that uses LiveStyle.

  Useful for testing and introspection.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        class :button, display: "flex"
      end

      # In tests:
      %LiveStyle.Attrs{class: class} = LiveStyle.Compiler.get_css(MyComponent, [:button])
  """
  @spec get_css(module(), list()) :: LiveStyle.Attrs.t()
  def get_css(module, refs) when is_atom(module) and is_list(refs) do
    # Usage is recorded at compile time via css/1 in templates.
    # For testing, use mark_all_used in test setup (already done by LiveStyle.TestCase).
    LiveStyle.Runtime.resolve_attrs(module, refs, nil)
  end

  @spec get_css(module(), atom()) :: LiveStyle.Attrs.t()
  def get_css(module, ref) when is_atom(module) and is_atom(ref) do
    # Usage is recorded at compile time via css/1 in templates.
    # For testing, use mark_all_used in test setup (already done by LiveStyle.TestCase).
    class_strings = module.__live_style__(:class_strings)
    %LiveStyle.Attrs{class: Keyword.get(class_strings, ref, ""), style: nil}
  end

  @doc """
  Gets the class string from a module that uses LiveStyle.

  Useful for testing and introspection.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        class :button, display: "flex"
      end

      # In tests:
      class = LiveStyle.Compiler.get_css_class(MyComponent, [:button])
  """
  @spec get_css_class(module(), list()) :: String.t()
  def get_css_class(module, refs) when is_atom(module) and is_list(refs) do
    # Usage is recorded at compile time via css/1 in templates.
    # For testing, use mark_all_used in test setup (already done by LiveStyle.TestCase).
    LiveStyle.Runtime.resolve_class_string(module, refs)
  end

  @spec get_css_class(module(), atom()) :: String.t()
  def get_css_class(module, ref) when is_atom(module) and is_atom(ref) do
    # Usage is recorded at compile time via css/1 in templates.
    # For testing, use mark_all_used in test setup (already done by LiveStyle.TestCase).
    class_strings = module.__live_style__(:class_strings)
    Keyword.get(class_strings, ref, "")
  end

  @doc """
  Generates CSS from all registered styles.

  Reads the manifest and generates the complete CSS output.
  Only classes that have been used via `css/1` are included (tree shaking).

  ## Example

      css = LiveStyle.Compiler.generate_css()
      # => ".x1234{display:flex} ..."
  """
  @spec generate_css() :: String.t()
  def generate_css do
    manifest = LiveStyle.Storage.read()
    CSSCompiler.compile(manifest)
  end
end
