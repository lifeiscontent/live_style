defmodule LiveStyle.Theme do
  @moduledoc """
  CSS theme support for variable overrides.

  Similar to StyleX's `createTheme`, this module handles creating themes
  that override CSS variables defined with `css_vars`.

  ## How Themes Work

  Themes generate a CSS class that overrides CSS variable values. When applied
  to an element, all descendants inherit the overridden values.

  ```css
  /* Generated theme class */
  .xabc123 {
    --text-primary: var(--colors-gray-50);
    --fill-page: var(--colors-gray-900);
  }
  ```

  ## Recommended Pattern

  Use a two-layer architecture for theming:

  1. **`:colors`** - Raw color palette (not themed)
  2. **`:semantic`** - Semantic tokens referencing colors (themed)

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Raw colors - the palette
        css_vars :colors,
          white: "#ffffff",
          gray_900: "#111827",
          gray_50: "#f9fafb",
          indigo_500: "#6366f1"

        # Semantic tokens - what components use
        css_vars :semantic,
          text_primary: css_var({:colors, :gray_900}),
          fill_page: css_var({:colors, :white})

        # Dark theme swaps which colors semantics point to
        css_theme :semantic, :dark,
          text_primary: css_var({:colors, :gray_50}),
          fill_page: css_var({:colors, :gray_900})
      end

  ## Applying Themes

  Use `css_theme/1` to get the theme class name:

      # Apply to a container
      <div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
        <!-- Children use dark theme -->
      </div>

      # Conditional theming
      <div class={@dark_mode && css_theme({MyApp.Tokens, :semantic, :dark})}>
        ...
      </div>

  ## Theme Scope

  Themes are scoped to their container and all descendants. This enables:

  - **Page-level themes**: Apply to `<html>` element
  - **Section themes**: Different themes for different page sections
  - **Component themes**: Override theme for specific components

      # Page-level theme on <html>
      <html class={@dark_mode && css_theme({MyApp.Tokens, :semantic, :dark})}>
        ...
      </html>

      # Section-level theme override
      <div class={css_theme({MyApp.Tokens, :semantic, :dark})}>
        <p>I'm dark themed</p>
      </div>
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest

  @doc """
  Defines a theme with variable overrides and stores it in the manifest.
  """
  @spec define(module(), atom(), atom(), map() | keyword(), String.t(), module() | nil) :: :ok
  def define(var_group_module, namespace, theme_name, overrides, css_name, theme_module \\ nil) do
    theme_module = theme_module || var_group_module
    key = Manifest.namespaced_key(theme_module, namespace, theme_name)

    # In test environment, skip if already exists to avoid race conditions
    if Mix.env() == :test do
      manifest = LiveStyle.Storage.read()

      unless Manifest.get_theme(manifest, key) do
        do_define_theme(key, var_group_module, namespace, overrides, css_name)
      end
    else
      do_define_theme(key, var_group_module, namespace, overrides, css_name)
    end

    :ok
  end

  defp do_define_theme(key, var_group_module, namespace, overrides, css_name) do
    overrides = normalize_to_map(overrides)

    # Convert override keys to CSS var names using the var group's module and namespace
    css_overrides =
      overrides
      |> Enum.map(fn {var_name, value} ->
        css_var_name = Hash.var_name(var_group_module, namespace, var_name)
        {css_var_name, value}
      end)
      |> Map.new()

    entry = %{
      css_name: css_name,
      var_group_module: var_group_module,
      var_group_namespace: namespace,
      overrides: css_overrides
    }

    LiveStyle.Storage.update(fn manifest ->
      Manifest.put_theme(manifest, key, entry)
    end)
  end

  @doc """
  Generates the CSS class name for a theme.
  """
  @spec generate_css_name(module(), atom(), atom()) :: String.t()
  def generate_css_name(module, namespace, theme_name) do
    Hash.theme_name(module, namespace, theme_name)
  end

  @doc """
  Looks up a theme by module, namespace, and theme name.
  Returns the css_name or raises if not found.
  """
  @spec lookup!(module(), atom(), atom()) :: String.t()
  def lookup!(module, namespace, theme_name) do
    key = Manifest.namespaced_key(module, namespace, theme_name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_theme(manifest, key) do
      %{css_name: css_name} ->
        css_name

      nil ->
        raise ArgumentError, """
        Unknown theme: #{inspect(module)}.#{namespace}.#{theme_name}

        Make sure css_theme(:#{namespace}, :#{theme_name}, ...) is defined before it's referenced.
        """
    end
  end

  # Normalize keyword list or map to map
  defp normalize_to_map(value) when is_map(value), do: value
  defp normalize_to_map(value) when is_list(value), do: Map.new(value)
end
