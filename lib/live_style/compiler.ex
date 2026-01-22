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
    # Record usage for tree shaking
    record_usage_from_refs(module, refs)
    LiveStyle.Runtime.resolve_attrs(module, refs, nil)
  end

  @spec get_css(module(), atom()) :: LiveStyle.Attrs.t()
  def get_css(module, ref) when is_atom(module) and is_atom(ref) do
    # Record usage for tree shaking
    record_usage(module, ref)
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
    # Record usage for tree shaking
    record_usage_from_refs(module, refs)
    LiveStyle.Runtime.resolve_class_string(module, refs)
  end

  @spec get_css_class(module(), atom()) :: String.t()
  def get_css_class(module, ref) when is_atom(module) and is_atom(ref) do
    # Record usage for tree shaking
    record_usage(module, ref)
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

  # Record usage for a single class reference
  defp record_usage(module, class_name) when is_atom(module) and is_atom(class_name) do
    LiveStyle.Storage.update_usage(fn usage ->
      LiveStyle.UsageManifest.record_usage(usage, module, class_name)
    end)
  end

  # Record usage from a list of refs (handles various ref formats)
  defp record_usage_from_refs(module, refs) when is_atom(module) and is_list(refs) do
    LiveStyle.Storage.update_usage(fn usage ->
      Enum.reduce(refs, usage, &record_ref_usage(&1, &2, module))
    end)
  end

  defp record_ref_usage(ref, acc, module) do
    case ref do
      # Simple atom ref
      name when is_atom(name) and name not in [nil, true, false] ->
        LiveStyle.UsageManifest.record_usage(acc, module, name)

      # Cross-module ref {OtherModule, :class}
      {other_module, name} when is_atom(other_module) and is_atom(name) ->
        LiveStyle.UsageManifest.record_usage(acc, other_module, name)

      # Dynamic tuple {:class, value}
      {name, _value} when is_atom(name) ->
        LiveStyle.UsageManifest.record_usage(acc, module, name)

      # Skip false/nil values from conditionals
      _ ->
        acc
    end
  end
end
