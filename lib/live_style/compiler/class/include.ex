defmodule LiveStyle.Compiler.Class.Include do
  @moduledoc """
  Style include resolution for LiveStyle.

  Handles `include/1` calls in style declarations, allowing styles to be
  composed from other styles in the same module or external modules. This follows
  StyleX's style composition pattern with last-wins semantics.

  ## Usage

      defmodule MyApp.Button do
        use LiveStyle

        class :base,
          display: "flex",
          padding: "8px"

        class :primary, [
          include(:base),
          background_color: "blue",
          color: "white"
        ]
      end

  The `:primary` class includes all declarations from `:base`, then merges
  its own declarations on top. Properties in the including class override
  properties from included classes (last-wins semantics).

  ## Cross-module Includes

  Include styles from other modules using a tuple:

      class :themed_button, [
        include({MyApp.BaseStyles, :btn_base}),
        color: var({MyApp.Tokens, :text_primary})
      ]

  ## Multiple Includes

  Include multiple classes - they are processed in order:

      class :fancy_button, [
        include(:base),
        include(:rounded),
        include({SharedStyles, :animated}),
        background: "linear-gradient(...)"
      ]

  ## Important Notes

  - Local includes must reference classes defined earlier in the same module
  - External module includes require the referenced module to be compiled first
  - Include resolution is recursive - included classes can themselves include other classes
  """

  alias LiveStyle.Manifest

  @doc """
  Resolves __include__ entries in a style declarations map.

  Include entries can be:
  - `:rule_name` - include from the same module
  - `{Module, :rule_name}` - include from another module

  The includes are processed in order, then remaining declarations are merged
  on top, giving later declarations precedence (last-wins semantics).
  """
  @spec resolve(map(), atom()) :: map()
  def resolve(declarations, caller_module) when is_map(declarations) do
    {includes_list, regular} = Map.pop(declarations, :__include__, [])

    # Normalize includes_list to always be a list
    includes_list = List.wrap(includes_list)

    base =
      includes_list
      |> Enum.reduce(%{}, fn include_ref, acc ->
        included = fetch_included_style(include_ref, caller_module)
        # Recursively resolve includes in the included style
        resolved = resolve(included, caller_module)
        Map.merge(acc, resolved)
      end)

    Map.merge(base, regular)
  end

  defp fetch_included_style({module, rule_name}, _caller_module)
       when is_atom(module) and is_atom(rule_name) do
    fetch_external_style(module, rule_name)
  end

  defp fetch_included_style(class_name, caller_module) when is_atom(class_name) do
    # Local reference - look up in storage
    key = Manifest.simple_key(caller_module, class_name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      %{declarations: declarations} ->
        declarations

      nil ->
        raise CompileError,
          description: """
          LiveStyle: Cannot include :#{class_name} - class not found.

          Local includes must refer to classes defined earlier in the same module.
          Make sure class(:#{class_name}, ...) is defined before it's included.
          """
    end
  end

  defp fetch_external_style(module, class_name) do
    Code.ensure_loaded!(module)

    key = Manifest.simple_key(module, class_name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      %{declarations: declarations} ->
        declarations

      nil ->
        raise CompileError,
          description: """
          LiveStyle: Class :#{class_name} not found in #{inspect(module)}.

          Make sure #{inspect(module)} is compiled before this module
          and defines class(:#{class_name}, ...).
          """
    end
  end
end
