defmodule LiveStyle.Include do
  @moduledoc """
  Style include resolution for LiveStyle.

  Handles the `__include__` key in style declarations, allowing styles to be
  composed from other styles in the same module or external modules.

  ## Example

      css_rule :base,
        display: "flex",
        padding: "8px"

      css_rule :button,
        __include__: [:base],
        background_color: "blue",
        color: "white"

  The `:button` rule will include all declarations from `:base`, then merge
  its own declarations on top (last-wins semantics).

  ## Cross-module includes

      css_rule :themed_button,
        __include__: [{OtherModule, :base_button}],
        color: css_var({Tokens, :text, :primary})
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

  defp fetch_included_style(rule_name, caller_module) when is_atom(rule_name) do
    # Local reference - look up in storage
    key = Manifest.simple_key(caller_module, rule_name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_rule(manifest, key) do
      %{declarations: declarations} ->
        declarations

      nil ->
        raise CompileError,
          description: """
          LiveStyle: Cannot include :#{rule_name} - rule not found.

          Local includes must refer to rules defined earlier in the same module.
          Make sure css_rule(:#{rule_name}, ...) is defined before it's included.
          """
    end
  end

  defp fetch_external_style(module, rule_name) do
    Code.ensure_loaded!(module)

    key = Manifest.simple_key(module, rule_name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_rule(manifest, key) do
      %{declarations: declarations} ->
        declarations

      nil ->
        raise CompileError,
          description: """
          LiveStyle: Rule :#{rule_name} not found in #{inspect(module)}.

          Make sure #{inspect(module)} is compiled before this module
          and defines css_rule(:#{rule_name}, ...).
          """
    end
  end
end
