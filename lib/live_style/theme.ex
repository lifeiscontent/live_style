defmodule LiveStyle.Theme do
  @moduledoc """
  CSS theme support for variable overrides.

  Similar to StyleX's `createTheme`, this module handles creating theme classes
  that override CSS variables defined with `vars`.

  ## How Themes Work

  Themes generate a CSS class that overrides CSS variable values. When applied
  to an element, all descendants inherit the overridden values.

  ```css
  /* Generated theme class */
  .t1abc23 {
    --v2def45: #000000;
    --v3ghi67: #ffffff;
  }
  ```

  ## Examples

      defmodule MyAppWeb.Tokens do
        use LiveStyle

        # Define variables
        vars text_primary: "#111827",
             fill_page: "#ffffff"

        # Create a dark theme that overrides those variables
        theme :dark,
          text_primary: "#f9fafb",
          fill_page: "#111827"
      end

  ## Applying Themes

  Use `theme/1` to get the theme class name:

      # Apply to a container
      <div class={theme({MyAppWeb.Tokens, :dark})}>
        <!-- Children use dark theme -->
      </div>

      # Conditional theming
      <div class={@dark_mode && theme({MyAppWeb.Tokens, :dark})}>
        ...
      </div>

  ## Theme Scope

  Themes are scoped to their container and all descendants.
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest
  alias LiveStyle.Utils

  use LiveStyle.Registry,
    entity_name: "Theme",
    manifest_type: :theme,
    ref_field: :ident

  # Identity-based CSS class name generation (private)
  defp ident(module, name) do
    input = "theme:#{inspect(module)}.#{name}"
    "t" <> Hash.create_hash(input)
  end

  # Generate CSS var name for override keys (matches Vars.ident/2)
  defp var_ident(module, name) do
    input = "var:#{inspect(module)}.#{name}"
    "--v" <> Hash.create_hash(input)
  end

  @doc """
  Defines a theme with variable overrides and stores it in the manifest.

  Called internally by the `theme` macro.

  Returns `{name, entry}` tuple for storage in module attributes.
  """
  @spec define(module(), atom(), keyword()) :: {atom(), keyword()}
  def define(module, name, overrides) do
    key = Manifest.key(module, name)
    overrides = Utils.validate_keyword_list!(overrides)

    theme_ident = ident(module, name)

    # Convert override keys to CSS var names and sort for deterministic iteration
    # Keep as sorted list - we only iterate, never lookup by key
    css_overrides =
      overrides
      |> Enum.map(fn {var_name, value} ->
        sorted_value = Utils.sort_conditional_value(value)
        {var_ident(module, var_name), sorted_value}
      end)
      |> Enum.sort_by(fn {k, _v} -> k end)

    entry = [ident: theme_ident, overrides: css_overrides]

    store_entry(key, entry)
    {name, entry}
  end
end
