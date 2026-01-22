defmodule LiveStyle.Class.Include do
  @moduledoc """
  Style include resolution for LiveStyle.

  Handles `include/1` calls in style declarations, allowing styles to be
  composed from other styles in the same module or external modules. This follows
  StyleX's style composition pattern with last-wins semantics.

  ## Usage

      defmodule MyAppWeb.Button do
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
        include({MyAppWeb.BaseStyles, :btn_base}),
        color: var({MyAppWeb.Tokens, :text_primary})
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

  alias LiveStyle.{Manifest, Utils}

  @doc """
  Resolves __include__ entries in style declarations.

  Include entries can be:
  - `:rule_name` - include from the same module
  - `{Module, :rule_name}` - include from another module

  The includes are processed in order, then remaining declarations are merged
  on top, giving later declarations precedence (last-wins semantics).

  ## Parameters

  - `declarations` - The style declarations to resolve
  - `caller_module` - The module defining the style
  - `manifest` - Optional manifest to look up local includes (for batch processing)
  """
  @spec resolve(keyword(), atom(), LiveStyle.Manifest.t() | nil) :: keyword()
  def resolve(declarations, caller_module, manifest \\ nil) when is_list(declarations) do
    {includes_list, regular} = Keyword.pop(declarations, :__include__, [])

    # Normalize includes_list to always be a list
    includes_list = List.wrap(includes_list)

    base =
      includes_list
      |> Enum.reduce([], fn include_ref, acc ->
        included = fetch_included_style(include_ref, caller_module, manifest)
        # Recursively resolve includes in the included style
        resolved = resolve(included, caller_module, manifest)
        Utils.merge_declarations(acc, resolved)
      end)

    Utils.merge_declarations(base, regular)
  end

  defp fetch_included_style({module, rule_name}, _caller_module, _manifest)
       when is_atom(module) and is_atom(rule_name) do
    # Record usage of the included external class for tree shaking
    record_include_usage(module, rule_name)

    # External references use __live_style__(:class, name) directly from the module
    fetch_external_style(module, rule_name)
  end

  defp fetch_included_style(class_name, caller_module, manifest) when is_atom(class_name) do
    # Record usage of the included local class for tree shaking
    record_include_usage(caller_module, class_name)

    # Local reference - look up in provided manifest first, then storage
    key = Manifest.key(caller_module, class_name)

    # Use provided manifest if available (for batch processing)
    # Otherwise fall back to storage
    manifest = manifest || LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      entry when is_list(entry) ->
        Keyword.fetch!(entry, :declarations)

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

    # First try module.__live_style__(:class, name) directly
    # This creates an automatic compile-time dependency and avoids file I/O race conditions
    # Fall back to storage for nested module compilation (same-file cross-module refs)
    case module.__live_style__(:class, class_name) do
      entry when is_list(entry) ->
        Keyword.fetch!(entry, :declarations)

      nil ->
        # Fallback: try storage (for nested modules in same file during compilation)
        key = Manifest.key(module, class_name)
        manifest = LiveStyle.Storage.read()

        case Manifest.get_class(manifest, key) do
          entry when is_list(entry) ->
            Keyword.fetch!(entry, :declarations)

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

  # Record usage of an included class for tree shaking
  defp record_include_usage(module, class_name) do
    LiveStyle.Storage.update_usage(fn usage ->
      LiveStyle.UsageManifest.record_usage(usage, module, class_name)
    end)
  end
end
