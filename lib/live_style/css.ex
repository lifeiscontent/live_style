defmodule LiveStyle.CSS do
  @moduledoc """
  CSS generation from LiveStyle manifest.

  This is an internal module responsible for generating the final CSS output
  from the compiled manifest. You typically don't use this module directly.

  ## Generated CSS Structure

  The CSS output includes (in order):

  1. **@property rules** - For typed CSS variables
  2. **CSS custom properties** - `:root { --var: value; }`
  3. **@keyframes animations** - With RTL variants when needed
  4. **@position-try rules** - For CSS Anchor Positioning
  5. **View transition rules** - `::view-transition-*` pseudo-elements
  6. **Atomic style rules** - Sorted by priority, with RTL overrides
  7. **Theme override rules** - `.theme-class { --var: override; }`

  ## Configuration

  CSS output can be configured via `LiveStyle.Config`:

  - `use_css_layers: true` - Group rules by priority in `@layer priorityN` blocks (StyleX `useLayers: true`)
  - `use_css_layers: false` (default) - Use `:not(#\\#)` selector hack (StyleX default)

  ## Writing CSS

  Use `LiveStyle.Compiler.write_css/1` or the mix tasks to generate CSS files.
  """

  alias LiveStyle.CSS.AtomicRules
  alias LiveStyle.CSS.Keyframes
  alias LiveStyle.CSS.PositionTry
  alias LiveStyle.CSS.Themes
  alias LiveStyle.CSS.Vars
  alias LiveStyle.CSS.ViewTransitions
  alias LiveStyle.Manifest

  @doc """
  Generates complete CSS from the manifest.
  """
  @spec generate(Manifest.t()) :: String.t()
  def generate(manifest) do
    [
      Vars.generate_properties(manifest),
      Vars.generate_vars(manifest),
      Keyframes.generate(manifest),
      PositionTry.generate(manifest),
      ViewTransitions.generate(manifest),
      AtomicRules.generate(manifest),
      Themes.generate(manifest)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc """
  Writes CSS to a file if it has changed.

  Delegates to `LiveStyle.CSS.Writer.write/2`.
  """
  @spec write(String.t(), keyword()) :: {:ok, :written | :unchanged} | {:error, term()}
  defdelegate write(path, opts \\ []), to: LiveStyle.CSS.Writer

  @doc """
  Expands selectors to include vendor-prefixed variants.

  Delegates to `LiveStyle.Selector.Prefixer.prefix/1`.

  See `LiveStyle.Selector.Prefixer` for the full list of supported selectors.
  """
  @spec prefix_selector(String.t()) :: String.t()
  defdelegate prefix_selector(selector), to: LiveStyle.Selector.Prefixer, as: :prefix
end
