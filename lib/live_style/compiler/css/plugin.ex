defmodule LiveStyle.Compiler.CSS.Plugin do
  @moduledoc """
  Behaviour for CSS plugins in the compilation pipeline.

  Each plugin is responsible for generating a specific type of CSS output
  from the manifest (e.g., variables, keyframes, atomic rules).

  ## Implementing a Plugin

      defmodule MyAppWeb.CSS.CustomPlugin do
        @behaviour LiveStyle.Compiler.CSS.Plugin

        @impl true
        def generate(manifest) do
          # Generate CSS from manifest
          "/* custom CSS */"
        end
      end

  ## Registering Plugins

  Add custom plugins to the pipeline via configuration:

      config :live_style,
        css_plugins: [
          {100, MyAppWeb.CSS.CustomPlugin}
        ]

  The tuple format is `{priority, module}` where lower priority runs first.

  ## Default Plugins

  The default pipeline (in order):

  1. `LiveStyle.Compiler.CSS.Vars` - @property rules for typed vars (priority 100)
  2. `LiveStyle.Compiler.CSS.DynamicProperties` - @property rules for dynamic vars (priority 150)
  3. `LiveStyle.Compiler.CSS.Vars` - :root variables (priority 200)
  4. `LiveStyle.Compiler.CSS.Keyframes` - @keyframes (priority 300)
  5. `LiveStyle.Compiler.CSS.PositionTry` - @position-try (priority 400)
  6. `LiveStyle.Compiler.CSS.ViewTransitionClasses` - view transitions (priority 500)
  7. `LiveStyle.Compiler.CSS.Classes` - style classes (priority 600)
  8. `LiveStyle.Compiler.CSS.ThemeClasses` - theme overrides (priority 700)
  """

  alias LiveStyle.Manifest

  @doc """
  Generates CSS output from the manifest.

  Returns a CSS string (may be empty if no relevant content).
  """
  @callback generate(Manifest.t()) :: String.t()

  @doc """
  Returns the list of registered plugins, sorted by priority.

  Each entry is a `{priority, {module, function}}` tuple.
  """
  @spec plugins() :: [{integer(), {module(), atom()}}]
  def plugins do
    (default_plugins() ++ custom_plugins())
    |> Enum.sort_by(fn {priority, _} -> priority end)
  end

  @doc """
  Returns the default plugin pipeline.

  The order matches StyleX:
  1. @property rules (typed vars)
  2. @property rules (dynamic vars)
  3. @keyframes animations
  4. :root variables
  5. @position-try rules
  6. View transition rules
  7. Atomic style rules
  8. Theme override rules
  """
  @spec default_plugins() :: [{integer(), {module(), atom()}}]
  def default_plugins do
    alias LiveStyle.Compiler.CSS.{
      Classes,
      DynamicProperties,
      Keyframes,
      PositionTry,
      ThemeClasses,
      Vars,
      ViewTransitionClasses
    }

    [
      {100, {Vars, :generate_properties}},
      {150, {DynamicProperties, :generate}},
      {200, {Keyframes, :generate}},
      {300, {Vars, :generate_vars}},
      {400, {PositionTry, :generate}},
      {500, {ViewTransitionClasses, :generate}},
      {600, {Classes, :generate}},
      {700, {ThemeClasses, :generate}}
    ]
  end

  @doc """
  Returns custom plugins from configuration.

  Custom plugins can be specified as:
  - `{priority, module}` - calls `module.generate/1`
  - `{priority, {module, :function}}` - calls `module.function/1`
  """
  @spec custom_plugins() :: [{integer(), {module(), atom()}}]
  def custom_plugins do
    Application.get_env(:live_style, :css_plugins, [])
    |> Enum.map(fn
      {priority, {module, function}} -> {priority, {module, function}}
      {priority, module} when is_atom(module) -> {priority, {module, :generate}}
    end)
  end
end
