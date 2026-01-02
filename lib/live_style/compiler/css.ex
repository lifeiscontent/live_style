defmodule LiveStyle.Compiler.CSS do
  @moduledoc """
  CSS compilation from LiveStyle manifest.

  This is an internal module responsible for compiling the final CSS output
  from the manifest. You typically don't use this module directly.

  ## Generated CSS Structure

  The CSS output includes (in order):

  1. **@property rules** - For typed CSS variables
  2. **@property rules** - For dynamic CSS variables (with `inherits: false`)
  3. **CSS custom properties** - `:root { --var: value; }`
  4. **@keyframes animations** - With RTL variants when needed
  5. **@position-try rules** - For CSS Anchor Positioning
  6. **View transition rules** - `::view-transition-*` pseudo-elements
  7. **Atomic style rules** - Sorted by priority, with RTL overrides
  8. **Theme override rules** - `.theme-class { --var: override; }`

  ## Extending the Pipeline

  Add custom plugins via configuration:

      config :live_style,
        css_plugins: [
          {250, MyAppWeb.CSS.CustomPlugin}
        ]

  See `LiveStyle.Compiler.CSS.Plugin` for details.

  ## Configuration

  CSS output can be configured via `LiveStyle.Config`:

  - `use_css_layers: true` - Group rules by priority in `@layer priorityN` blocks (StyleX `useLayers: true`)
  - `use_css_layers: false` (default) - Use `:not(#\\#)` selector hack (StyleX default)

  ## Writing CSS

  Use the mix tasks (`mix live_style` or `mix compile.live_style`) to generate CSS files.
  """

  alias LiveStyle.Compiler.CSS.Plugin
  alias LiveStyle.Manifest

  @doc """
  Compiles complete CSS from the manifest.

  Runs all registered plugins in priority order and joins their output.
  """
  @spec compile(Manifest.t()) :: String.t()
  def compile(manifest) do
    Plugin.plugins()
    |> Enum.map(fn {_priority, {module, function}} ->
      apply(module, function, [manifest])
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc """
  Writes CSS to a file if it has changed.

  Delegates to `LiveStyle.Compiler.CSS.Writer.write/2`.
  """
  @spec write(String.t(), keyword()) :: {:ok, :written | :unchanged} | {:error, term()}
  defdelegate write(path, opts \\ []), to: LiveStyle.Compiler.CSS.Writer

  @doc """
  Expands selectors to include vendor-prefixed variants.

  Delegates to `LiveStyle.Selector.Prefixer.prefix/1`.

  See `LiveStyle.Selector.Prefixer` for the full list of supported selectors.
  """
  @spec prefix_selector(String.t()) :: String.t()
  defdelegate prefix_selector(selector), to: LiveStyle.Selector.Prefixer, as: :prefix
end
