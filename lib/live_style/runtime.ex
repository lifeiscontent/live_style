defmodule LiveStyle.Runtime do
  @moduledoc """
  Runtime helpers for LiveStyle style resolution.

  This module handles runtime operations for resolving style references:
  - Class string resolution from refs
  - Property-based merging (StyleX behavior)
  - Dynamic rule processing
  - Cross-module reference resolution

  Note: Class reference validation is done at compile time by the
  class/2 and css/1 macros in LiveStyle.
  """

  alias LiveStyle.Runtime.{Attrs, ClassString}

  @doc """
  Resolve a list of refs into a class string.

  Later refs override earlier ones (StyleX merge behavior).
  Validation is done at compile time by the class/2 macro.
  """
  @spec resolve_class_string(module(), list()) :: String.t()
  def resolve_class_string(module, refs) when is_list(refs) do
    ClassString.resolve_class_string(module, refs)
  end

  @doc """
  Resolve a list of refs into an Attrs struct with class and style.

  Handles both static rules and dynamic rules with CSS variables.
  Optionally merges additional inline styles from the `opts` parameter.

  ## Options

    * `:style` - A keyword list or map of CSS properties to merge into the style.

  Validation is done at compile time by the css/1 macro.
  """
  @spec resolve_attrs(module(), list(), keyword() | nil) :: LiveStyle.Attrs.t()
  def resolve_attrs(module, refs, opts) when is_list(refs) do
    Attrs.resolve_attrs(module, refs, opts)
  end
end
