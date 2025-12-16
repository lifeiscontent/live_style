defmodule LiveStyle do
  @moduledoc """
  Atomic CSS-in-Elixir for Phoenix LiveView, inspired by Meta's StyleX.

  LiveStyle provides a fully static styling system - all CSS is generated at
  compile/build time, just like Tailwind. No runtime style generation.

  ## Configuration

  Add to your `config/config.exs`:

      config :live_style,
        output_path: "priv/static/assets/live.css",
        manifest_path: "_build/live_style_manifest.etf"

  ### Options

  - `:output_path` - Path where the generated CSS file is written.
    Defaults to `"priv/static/assets/live.css"`.

  - `:manifest_path` - Path where the compile-time manifest is stored.
    Defaults to `"_build/live_style_manifest.etf"`. Useful for monorepos
    or custom build directories.

  ## Quick Start

      defmodule MyAppWeb.Components.Button do
        use Phoenix.Component
        use LiveStyle

        # Keyword list syntax (idiomatic Elixir)
        style :base,
          display: "flex",
          align_items: "center",
          padding: "8px 16px",
          border_radius: "8px"

        style :primary,
          background_color: var(:fill_primary),
          color: var(:color_white)

        # Map syntax also works
        style :secondary, %{
          background_color: var(:fill_secondary),
          color: var(:text_primary)
        }

        attr :variant, :atom, default: :primary
        slot :inner_block, required: true

        def button(assigns) do
          ~H\"\"\"
          <button class={style([:base, @variant])}>
            {render_slot(@inner_block)}
          </button>
          \"\"\"
        end
      end

  ## How It Works

  1. **Compile time**: `style :name, %{...}` generates atomic class names and
     writes CSS rules to a manifest file
  2. **Template time**: `style([:base, :primary])` does a simple map lookup
     on compile-time-baked data - no CSS generation
  3. **Build time**: `mix live_style.gen.css` reads the manifest and outputs CSS

  ## Features

  - **Declarative**: `style :name, %{...}` mirrors Phoenix's `attr` and `slot`
  - **Composable**: `style([:base, :variant])` merges with last-wins semantics
  - **Conditional**: `style([:base, @active && :active])` - falsy values filtered
  - **Native**: Returns a string for `class={...}` - no spreading needed
  - **Static**: All CSS determined at compile time, like Tailwind
  - **No Runtime**: For dynamic styles, use inline `style` attribute or JS

  ## Design Tokens

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Keyword list syntax
        defvars :color,
          white: "#ffffff",
          black: "#000000",
          primary: "#1e68fa"

        # Map syntax also works
        defvars :radius, %{
          sm: "0.125rem",
          md: "0.25rem",
          lg: "0.5rem"
        }
      end

  ## CSS Output

      mix live_style.gen.css
  """

  # CSS property priority for deterministic ordering
  @property_priority %{
    # Layout
    "display" => 100,
    "position" => 101,
    "visibility" => 102,
    "overflow" => 103,
    "overflow-x" => 104,
    "overflow-y" => 105,
    # Flexbox
    "flex" => 200,
    "flex-direction" => 201,
    "flex-wrap" => 202,
    "flex-grow" => 203,
    "flex-shrink" => 204,
    "flex-basis" => 205,
    "align-items" => 210,
    "align-self" => 211,
    "align-content" => 212,
    "justify-content" => 213,
    "justify-items" => 214,
    "justify-self" => 215,
    "order" => 220,
    "gap" => 230,
    "row-gap" => 231,
    "column-gap" => 232,
    # Grid
    "grid-template-columns" => 300,
    "grid-template-rows" => 301,
    "grid-column" => 310,
    "grid-row" => 311,
    "grid-area" => 312,
    # Box Model - Size
    "width" => 400,
    "height" => 401,
    "min-width" => 402,
    "max-width" => 403,
    "min-height" => 404,
    "max-height" => 405,
    # Box Model - Spacing
    "margin" => 500,
    "margin-top" => 501,
    "margin-right" => 502,
    "margin-bottom" => 503,
    "margin-left" => 504,
    "padding" => 510,
    "padding-top" => 511,
    "padding-right" => 512,
    "padding-bottom" => 513,
    "padding-left" => 514,
    # Position
    "top" => 600,
    "right" => 601,
    "bottom" => 602,
    "left" => 603,
    "inset" => 604,
    "z-index" => 610,
    # Typography
    "font-family" => 700,
    "font-size" => 701,
    "font-weight" => 702,
    "font-style" => 703,
    "line-height" => 710,
    "letter-spacing" => 711,
    "text-align" => 720,
    "text-decoration" => 721,
    "text-transform" => 722,
    "white-space" => 730,
    "word-break" => 731,
    "overflow-wrap" => 732,
    # Colors
    "color" => 800,
    "background" => 810,
    "background-color" => 811,
    "background-image" => 812,
    "background-size" => 813,
    "background-repeat" => 814,
    "background-position" => 815,
    # Borders
    "border" => 900,
    "border-width" => 901,
    "border-style" => 902,
    "border-color" => 903,
    "border-radius" => 910,
    "border-top" => 920,
    "border-top-width" => 921,
    "border-top-style" => 922,
    "border-top-color" => 923,
    "border-right" => 924,
    "border-right-width" => 925,
    "border-right-style" => 926,
    "border-right-color" => 927,
    "border-bottom" => 928,
    "border-bottom-width" => 929,
    "border-bottom-style" => 930,
    "border-bottom-color" => 931,
    "border-left" => 932,
    "border-left-width" => 933,
    "border-left-style" => 934,
    "border-left-color" => 935,
    "border-top-left-radius" => 940,
    "border-top-right-radius" => 941,
    "border-bottom-right-radius" => 942,
    "border-bottom-left-radius" => 943,
    # Effects
    "opacity" => 1000,
    "box-shadow" => 1001,
    "filter" => 1002,
    "backdrop-filter" => 1003,
    "transform" => 1010,
    "transition" => 1020,
    "transition-property" => 1021,
    "transition-duration" => 1022,
    "transition-timing-function" => 1023,
    "animation" => 1030,
    "animation-name" => 1031,
    "animation-duration" => 1032,
    "animation-timing-function" => 1033,
    "animation-iteration-count" => 1034,
    # Interactivity
    "cursor" => 1100,
    "pointer-events" => 1101,
    "user-select" => 1102,
    "outline" => 1110,
    "outline-width" => 1111,
    "outline-style" => 1112,
    "outline-color" => 1113,
    "outline-offset" => 1114,
    # Misc
    "object-fit" => 1200,
    "object-position" => 1201,
    "vertical-align" => 1202
  }

  @default_manifest_path "_build/live_style_manifest.etf"
  @default_output_path "priv/static/assets/live.css"

  @doc """
  Normalizes a keyword list or map to a map.

  This allows all LiveStyle macros to accept either syntax:

      # Map syntax (original)
      style :button, %{display: "flex", padding: "8px"}

      # Keyword list syntax (more idiomatic Elixir)
      style :button, display: "flex", padding: "8px"

  Nested values are also normalized recursively:

      style :button, [
        color: [
          default: "blue",
          ":hover": "darkblue"
        ]
      ]

  ## Implementation Note

  This function is public because it needs to be called at runtime during
  macro expansion (Code.eval_quoted evaluates at compile time but the
  result needs to be normalized).
  """
  @spec normalize_to_map(map() | keyword()) :: map()
  def normalize_to_map(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, normalize_to_map(v)} end)
  end

  def normalize_to_map(data) when is_list(data) do
    if Keyword.keyword?(data) do
      Map.new(data, fn {k, v} -> {k, normalize_to_map(v)} end)
    else
      data
    end
  end

  def normalize_to_map(data), do: data

  @doc """
  Returns the configured output path for the generated CSS file.

  Defaults to `"priv/static/assets/live.css"`. Can be configured with:

      config :live_style, output_path: "assets/css/live.css"
  """
  @spec output_path() :: String.t()
  def output_path do
    Application.get_env(:live_style, :output_path, @default_output_path)
  end

  @doc """
  Returns the configured manifest path for compile-time data.

  Defaults to `"_build/live_style_manifest.etf"`. Can be configured with:

      config :live_style, manifest_path: "_build/my_app/live_style.etf"
  """
  @spec manifest_path() :: String.t()
  def manifest_path do
    Application.get_env(:live_style, :manifest_path, @default_manifest_path)
  end

  defp lock_path do
    manifest_path() |> Path.rootname() |> Kernel.<>(".lock")
  end

  @doc false
  def read_manifest do
    case File.read(manifest_path()) do
      {:ok, ""} -> %{rules: %{}, vars: %{}, keyframes: %{}}
      {:ok, binary} -> :erlang.binary_to_term(binary)
      {:error, _} -> %{rules: %{}, vars: %{}, keyframes: %{}}
    end
  end

  @doc false
  def write_manifest(manifest) do
    path = manifest_path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(manifest))
  end

  @doc false
  def update_manifest(fun) when is_function(fun, 1) do
    lock = lock_path()
    File.mkdir_p!(Path.dirname(lock))

    with_lock(lock, fn ->
      manifest = read_manifest()
      new_manifest = fun.(manifest)
      write_manifest(new_manifest)
      new_manifest
    end)
  end

  defp with_lock(lock_file, fun) do
    acquire_lock(lock_file, 100)

    try do
      fun.()
    after
      release_lock(lock_file)
    end
  end

  defp acquire_lock(_lock_file, 0), do: :ok

  defp acquire_lock(lock_file, retries) do
    case File.write(lock_file, "#{System.monotonic_time()}", [:exclusive]) do
      :ok ->
        :ok

      {:error, :eexist} ->
        Process.sleep(5)
        acquire_lock(lock_file, retries - 1)

      {:error, _} ->
        :ok
    end
  end

  defp release_lock(lock_file) do
    File.rm(lock_file)
  end

  defmacro __using__(_opts) do
    quote do
      import LiveStyle, only: [style: 2, keyframes: 2, var: 1, first_that_works: 1, conditions: 1]

      Module.register_attribute(__MODULE__, :__live_styles__, accumulate: true)
      Module.register_attribute(__MODULE__, :__live_keyframes__, accumulate: true)

      @before_compile LiveStyle
    end
  end

  defmacro __before_compile__(env) do
    styles = Module.get_attribute(env.module, :__live_styles__) |> Enum.reverse()
    keyframes_defs = Module.get_attribute(env.module, :__live_keyframes__) |> Enum.reverse()

    # First pass: collect raw styles for include resolution
    raw_styles_map = Map.new(styles)

    # Second pass: resolve includes for each style
    resolved_styles =
      styles
      |> Enum.map(fn {name, declarations} ->
        resolved = LiveStyle.resolve_includes(declarations, raw_styles_map, env.module)
        {name, resolved}
      end)

    raw_styles = Map.new(resolved_styles)

    keyframes_map =
      keyframes_defs
      |> Enum.map(fn {name, _frames} ->
        keyframe_name = LiveStyle.generate_keyframe_name(name, env.module)
        {name, keyframe_name}
      end)
      |> Map.new()

    styles_map =
      resolved_styles
      |> Enum.map(fn {name, declarations} ->
        atomic = LiveStyle.process_style_map(declarations, keyframes_map)
        {name, atomic}
      end)
      |> Map.new()

    class_strings =
      styles_map
      |> Enum.map(fn {name, atomic} ->
        class_string = atomic |> Map.values() |> Enum.join(" ")
        {name, class_string}
      end)
      |> Map.new()

    for {name, frames} <- keyframes_defs do
      keyframe_name = Map.fetch!(keyframes_map, name)
      LiveStyle.register_keyframes(keyframe_name, frames)
    end

    quote do
      @__raw_styles__ unquote(Macro.escape(raw_styles))
      @__styles_map__ unquote(Macro.escape(styles_map))
      @__class_strings__ unquote(Macro.escape(class_strings))

      @doc false
      def __live_style__(name) do
        Map.get(@__raw_styles__, name)
      end

      defp style(refs) when is_list(refs) do
        refs
        |> Enum.filter(& &1)
        |> Enum.reduce(%{}, fn ref, acc ->
          case Map.fetch(@__styles_map__, ref) do
            {:ok, atomic} -> Map.merge(acc, atomic)
            :error -> acc
          end
        end)
        |> Map.values()
        |> Enum.join(" ")
      end

      defp style(ref) when is_atom(ref) do
        Map.get(@__class_strings__, ref, "")
      end
    end
  end

  @doc """
  Declares a named style.

  Accepts either map or keyword list syntax:

      # Map syntax
      style :base, %{
        display: "flex",
        padding: "8px 16px"
      }

      # Keyword list syntax (more idiomatic Elixir)
      style :base,
        display: "flex",
        padding: "8px 16px"

      style :primary,
        background_color: var(:fill_primary),
        color: var(:color_white)

      # With pseudo-classes
      style :link,
        color: "blue",
        ":hover": [color: "darkblue"]

      # With media queries
      style :responsive,
        padding: "8px",
        "@media (min-width: 768px)": [padding: "16px"]

      # With include for composition from other modules
      style :primary_button,
        __include__: [{BaseStyles, :button}],
        background_color: var(:fill_primary)

      # With include for self-references (same module)
      style :large_primary_button,
        __include__: [:primary_button],
        font_size: "1.25rem"
  """
  defmacro style(name, declarations) when is_atom(name) do
    # Defer all evaluation to the module body context where module attributes
    # are properly resolved. The declarations AST will be evaluated when the
    # @__live_styles__ attribute is set.
    quote do
      # Evaluate declarations in this module's context (module attrs available)
      # and normalize keyword lists to maps
      evaluated_decl = LiveStyle.normalize_to_map(unquote(declarations))

      # Store for processing in __before_compile__
      @__live_styles__ {unquote(name), evaluated_decl}

      # Also store and process immediately for include support
      LiveStyle.store_module_style(__MODULE__, unquote(name), evaluated_decl)
    end
  end

  @doc """
  Declares a named keyframes animation.

  Accepts either map or keyword list syntax:

      # Map syntax
      keyframes :spin, %{
        from: %{transform: "rotate(0deg)"},
        to: %{transform: "rotate(360deg)"}
      }

      # Keyword list syntax
      keyframes :spin,
        from: [transform: "rotate(0deg)"],
        to: [transform: "rotate(360deg)"]

      style :spinner, animation_name: :spin, animation_duration: "1s"
  """
  defmacro keyframes(name, frames) when is_atom(name) do
    {evaluated_frames, _} = Code.eval_quoted(frames, [], __CALLER__)
    normalized_frames = LiveStyle.normalize_to_map(evaluated_frames)

    quote do
      @__live_keyframes__ {unquote(name), unquote(Macro.escape(normalized_frames))}
    end
  end

  @doc """
  Creates a CSS variable reference from an atom.

  Generates a deterministic hashed CSS variable name at compile time.
  No runtime lookup - the hash is computed from the atom name.

  ## Example

      style :button, %{
        background_color: var(:fill_primary),
        color: var(:text_white),
        border_radius: var(:radius_lg),
        box_shadow: var(:shadow_lg)
      }

  This generates CSS like:

      .x123 { background-color: var(--v1a2b3c4); }
      .x456 { color: var(--v5e6f7g8); }

  ## Naming Convention

  Use the pattern `namespace_name`:
  - `var(:color_blue_500)` → `var(--v...)` (hash of "color:blue_500")
  - `var(:text_primary)` → `var(--v...)` (hash of "text:primary")
  - `var(:fill_primary)` → `var(--v...)` (hash of "fill:primary")
  - `var(:radius_lg)` → `var(--v...)` (hash of "radius:lg")

  ## Important

  The var name MUST match a variable defined with `defvars` in your tokens module.
  The naming convention is `namespace_name` where namespace and name are joined
  by underscore. This allows deterministic hash generation without runtime lookups.
  """
  defmacro var(name) when is_atom(name) do
    name_str = Atom.to_string(name)

    {namespace, var_name} =
      case String.split(name_str, "_", parts: 2) do
        [ns, rest] -> {ns, rest}
        [single] -> {"vars", single}
      end

    css_var_name = generate_var_name(namespace, var_name)
    file = __CALLER__.file
    line = __CALLER__.line
    LiveStyle.record_var_usage(css_var_name, name, file, line)

    "var(#{css_var_name})"
  end

  @doc """
  Declares an ordered list of fallback values for a style property.

  All fallbacks are included in the generated CSS so that the browser
  uses the first supported value in the list.

  ## Example

      style :header, %{
        position: first_that_works(["sticky", "-webkit-sticky", "fixed"])
      }

  This generates CSS like:

      .x123 {
        position: fixed;
        position: -webkit-sticky;
        position: sticky;
      }

  The browser will use `sticky` if supported, fall back to `-webkit-sticky`,
  and finally to `fixed` if neither is supported.
  """
  defmacro first_that_works(values) when is_list(values) do
    quote do
      %{__first_that_works__: true, values: unquote(values)}
    end
  end

  @doc """
  Returns the default marker class name for use with `LiveStyle.When` selectors.

  Apply this class to elements you want to observe for state changes (hover, focus, etc.)
  when using contextual selectors like `ancestor/1`, `descendant/1`, or `sibling_*/1`.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        import LiveStyle.When

        style(:card_content, %{
          transform: %{
            default: "translateX(0)",
            ancestor(":hover"): "translateX(10px)"
          }
        })

        def render(assigns) do
          ~H\"\"\"
          <div class={LiveStyle.default_marker()}>
            <div class={style(:card_content)}>
              Hover the parent to move me
            </div>
          </div>
          \"\"\"
        end
      end
  """
  def default_marker, do: "x-marker"

  @doc """
  Generates a unique marker class name for use with `LiveStyle.When` selectors.

  Custom markers allow you to have multiple independent sets of contextual selectors
  in the same component tree.

  ## Parameters

    * `name` - An atom identifying this marker

  ## Example

      defmodule MyApp.Markers do
        @card_marker LiveStyle.define_marker(:card)
        @row_marker LiveStyle.define_marker(:row)

        def card_marker, do: @card_marker
        def row_marker, do: @row_marker
      end

      defmodule MyComponent do
        use LiveStyle
        import LiveStyle.When
        alias MyApp.Markers

        style(:heading, %{
          transform: %{
            default: "translateX(0)",
            ancestor(":hover", Markers.card_marker()): "translateX(10px)",
            ancestor(":hover", Markers.row_marker()): "translateX(4px)"
          }
        })
      end
  """
  def define_marker(name) when is_atom(name) do
    hash =
      :crypto.hash(:md5, "marker:#{name}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "x-marker-#{hash}"
  end

  @doc """
  Builds a conditional value map from a list of `{condition, value}` tuples.

  This helper allows using module attributes and computed values as condition keys,
  which isn't possible with map literal syntax.

  ## Example

      import LiveStyle.When

      @row_marker LiveStyle.define_marker(:row)
      @row_hover ancestor(":hover", @row_marker)
      @col1_hover ":where(:has(td:nth-of-type(1):hover))"

      style(:td, %{
        background_color: conditions([
          {:default, "transparent"},
          {@row_hover, var(:color_indigo_50)},
          {@col1_hover, var(:color_indigo_50)},
          {":hover", var(:color_indigo_200)}
        ])
      })

  This is equivalent to:

      style(:td, %{
        background_color: %{
          :default => "transparent",
          ":where(.x-marker-abc:hover *)" => var(:color_indigo_50),
          ":where(:has(td:nth-of-type(1):hover))" => var(:color_indigo_50),
          ":hover" => var(:color_indigo_200)
        }
      })
  """
  defmacro conditions(condition_list) do
    # Return code that builds the map in the caller's module context
    # This allows module attributes (@foo) to be resolved correctly
    quote do
      Map.new(unquote(condition_list))
    end
  end

  @doc """
  Include styles at compile time using the `__include__` key.

  This copies style properties from other sources into the current style
  definition. The inclusion happens at compile time with zero runtime overhead.

  ## Include Types

  The `__include__` key accepts a list with two types of references:

  - `{Module, :style_name}` - include from another module
  - `:style_name` - include from the same module (self-reference)

  ## Example - External Module Include

      # Define base styles in a shared module
      defmodule MyApp.BaseStyles do
        use LiveStyle

        style :button_base, %{
          display: "inline-flex",
          padding: "8px 16px",
          cursor: "pointer"
        }
      end

      # Include in your component
      defmodule MyApp.Button do
        use LiveStyle

        style :primary, %{
          __include__: [{MyApp.BaseStyles, :button_base}],
          background_color: var(:fill_primary)
        }
      end

  ## Example - Self-Reference Include

      defmodule MyApp.Button do
        use LiveStyle

        # Base style defined first
        style :base, %{
          display: "inline-flex",
          padding: "8px 16px",
          cursor: "pointer"
        }

        # Self-reference to :base (must be defined above)
        style :primary, %{
          __include__: [:base],
          background_color: var(:fill_primary)
        }

        # Chain includes - :large includes :primary which includes :base
        style :large, %{
          __include__: [:primary],
          font_size: "1.25rem",
          padding: "12px 24px"
        }
      end

  ## Example - Mixed Includes

      style :fancy_button, %{
        __include__: [
          {MyApp.BaseStyles, :interactive},  # from another module
          :base,                              # from same module
          {MyApp.Themes, :gradient}           # from another module
        ],
        box_shadow: "0 4px 6px rgba(0,0,0,0.1)"
      }

  ## How It Works

  Includes are processed in order (first to last), then local declarations
  are merged on top. This gives local declarations highest precedence:

  1. First include's declarations form the base
  2. Each subsequent include merges on top
  3. Local declarations (non-include) merge last and override everything

  ## Important

  - External modules must be compiled before the current module
  - Self-references must refer to styles defined earlier in the same module
  - The `__include__` key is reserved and won't appear in final style
  """
  defmacro include(_module, _style_name) do
    raise CompileError,
      description: """
      LiveStyle: The include/2 macro cannot be used directly in a map.

      Use the __include__ key instead:

          # External module include
          style :my_style, %{
            __include__: [{OtherModule, :style_name}],
            color: "blue"
          }

          # Self-reference (same module)
          style :my_style, %{
            __include__: [:base_style],
            color: "blue"
          }

      For multiple includes:

          style :my_style, %{
            __include__: [
              {BaseModule, :base},
              {ThemeModule, :colors}
            ],
            padding: "16px"
          }
      """
  end

  @doc """
  Define CSS custom properties (variables) at compile time.

  This macro is used in token modules to define design tokens.
  The variables are written to the manifest file during compilation.

  Accepts either map or keyword list syntax:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Map syntax
        defvars :color, %{
          white: "#ffffff",
          black: "#000000",
          blue_500: "#1e68fa"
        }

        # Keyword list syntax
        defvars :radius,
          sm: "0.125rem",
          lg: "0.5rem"
      end
  """
  defmacro defvars(namespace, vars) when is_atom(namespace) do
    {evaluated_vars, _} = Code.eval_quoted(vars, [], __CALLER__)
    evaluated_vars = LiveStyle.normalize_to_map(evaluated_vars)
    namespace_str = Atom.to_string(namespace)

    {var_defs, property_defs} =
      evaluated_vars
      |> Enum.reduce({%{}, %{}}, fn {name, value}, {vars_acc, props_acc} ->
        name_str = Atom.to_string(name)
        css_var_name = LiveStyle.generate_var_name(namespace_str, name_str)

        case value do
          %{__type__: :typed_var, syntax: syntax, value: inner_value} ->
            css_value = extract_css_value(inner_value)
            initial = LiveStyle.Types.initial_value(value)

            vars_acc = Map.put(vars_acc, css_var_name, css_value)
            props_acc = Map.put(props_acc, css_var_name, %{syntax: syntax, initial: initial})
            {vars_acc, props_acc}

          _ ->
            vars_acc = Map.put(vars_acc, css_var_name, value)
            {vars_acc, props_acc}
        end
      end)

    LiveStyle.update_manifest(fn manifest ->
      vars = Map.merge(manifest[:vars] || %{}, var_defs)
      properties = Map.merge(manifest[:properties] || %{}, property_defs)

      manifest
      |> Map.put(:vars, vars)
      |> Map.put(:properties, properties)
    end)

    quote do
    end
  end

  defp extract_css_value(value) when is_binary(value), do: value
  defp extract_css_value(value) when is_integer(value), do: to_string(value)
  defp extract_css_value(value) when is_float(value), do: to_string(value)

  defp extract_css_value(%{default: _default} = map) when is_map(map) do
    map
    |> Enum.map(fn
      {:default, v} -> {:default, to_string(v)}
      {k, v} -> {to_string(k), to_string(v)}
    end)
    |> Map.new()
  end

  defp extract_css_value(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Map.new()
  end

  @doc """
  Define static constants that are inlined at build time.

  Unlike `defvars`, these values do not generate CSS custom properties.
  They are directly substituted into styles at compile time. This is useful
  for values that are used as condition keys (media queries, etc.) or values
  that should be inlined rather than referenced via CSS variables.

  Accepts either map or keyword list syntax:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Map syntax
        defconsts :breakpoints, %{
          sm: "@media (max-width: 640px)",
          md: "@media (min-width: 641px) and (max-width: 1024px)",
          lg: "@media (min-width: 1025px)"
        }

        # Keyword list syntax
        defconsts :z,
          modal: "1000",
          tooltip: "1100",
          toast: "1200"
      end

  Then use in styles:

      import MyApp.Tokens

      style :responsive,
        padding: [
          default: "8px",
          {breakpoints_sm(), "4px"},
          {breakpoints_lg(), "16px"}
        ]
  """
  defmacro defconsts(namespace, consts) when is_atom(namespace) do
    {evaluated_consts, _} = Code.eval_quoted(consts, [], __CALLER__)
    evaluated_consts = LiveStyle.normalize_to_map(evaluated_consts)
    namespace_str = Atom.to_string(namespace)

    const_definitions =
      Enum.map(evaluated_consts, fn {name, value} ->
        func_name = String.to_atom("#{namespace_str}_#{name}")

        quote do
          @doc false
          def unquote(func_name)(), do: unquote(value)
        end
      end)

    const_map = Macro.escape(evaluated_consts)

    quote do
      unquote_splicing(const_definitions)

      @doc false
      def unquote(namespace)(), do: unquote(const_map)
    end
  end

  @doc """
  Define a keyframes animation and create a function that returns its name.

  This follows the StyleX pattern where `keyframes` returns a string that can
  be used in animation properties.

  Accepts either map or keyword list syntax:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        # Map syntax
        defkeyframes :spin, %{
          from: %{transform: "rotate(0deg)"},
          to: %{transform: "rotate(360deg)"}
        }

        # Keyword list syntax
        defkeyframes :fade_in,
          from: [opacity: "0"],
          to: [opacity: "1"]
      end

      # Use the generated functions:
      MyApp.Tokens.spin()     # => "k1a2b3c4" (the hashed keyframe name)
      MyApp.Tokens.fade_in()  # => "k5e6f7g8"

      # In styles or view transitions:
      view_transition "card-*",
        old: [animation: "\#{fade_out()} 200ms ease-out both"]
  """
  defmacro defkeyframes(name, frames) when is_atom(name) do
    {evaluated_frames, _} = Code.eval_quoted(frames, [], __CALLER__)
    evaluated_frames = LiveStyle.normalize_to_map(evaluated_frames)

    frames_string = inspect(evaluated_frames, limit: :infinity)

    hash =
      :crypto.hash(:md5, frames_string)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    keyframe_name = "k#{hash}"
    LiveStyle.register_keyframes(keyframe_name, evaluated_frames)

    # Define a function that returns the keyframe name string
    # This follows StyleX's pattern where keyframes() returns a string
    # Also store in module attribute for compile-time access by view_transition
    quote do
      @__live_keyframes_map__ {unquote(name), unquote(keyframe_name)}

      @doc """
      Returns the generated keyframe name for `#{unquote(name)}`.

      Use this in animation properties:

          animation: "\#{#{unquote(name)}()} 1s ease-out"
          animation_name: #{unquote(name)}()
      """
      def unquote(name)(), do: unquote(keyframe_name)
    end
  end

  @doc """
  Creates a theme that overrides CSS variable values for a subtree.

  Takes a namespace (matching one defined with `defvars`) and a map of
  overrides. Returns a class name that when applied to an element,
  overrides those CSS variables for that element and its descendants.

  Accepts either map or keyword list syntax:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        defvars :fill, primary: "#3b82f6", secondary: "#e5e7eb"

        # Map syntax
        create_theme :dark_fill, :fill, %{
          primary: "#60a5fa",
          secondary: "#374151"
        }

        # Keyword list syntax
        create_theme :dark_fill, :fill,
          primary: "#60a5fa",
          secondary: "#374151"
      end

  Then use in templates:

      <div class={MyApp.Tokens.dark_fill()}>
        <!-- All components in here use dark theme colors -->
      </div>
  """
  defmacro create_theme(theme_name, namespace, overrides)
           when is_atom(theme_name) and is_atom(namespace) do
    {evaluated_overrides, _} = Code.eval_quoted(overrides, [], __CALLER__)
    evaluated_overrides = LiveStyle.normalize_to_map(evaluated_overrides)
    namespace_str = Atom.to_string(namespace)

    declarations =
      Enum.map_join(evaluated_overrides, " ", fn {name, value} ->
        name_str = Atom.to_string(name)
        css_var_name = LiveStyle.generate_var_name(namespace_str, name_str)
        "#{css_var_name}: #{value};"
      end)

    theme_hash =
      :crypto.hash(:md5, "#{namespace}:#{inspect(evaluated_overrides)}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    class_name = "t#{theme_hash}"
    css_rule = ".#{class_name} { #{declarations} }"
    LiveStyle.register_rule(class_name, css_rule, 0)

    quote do
      @doc "Returns the class name for the #{unquote(theme_name)} theme"
      def unquote(theme_name)(), do: unquote(class_name)
    end
  end

  @doc """
  Returns complete CSS output from the manifest.
  """
  @spec get_all_css() :: String.t()
  def get_all_css do
    manifest = read_manifest()

    [
      get_properties_css(manifest),
      get_vars_css(manifest),
      get_keyframes_css(manifest),
      get_view_transitions_css(manifest),
      get_rules_css(manifest)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp get_properties_css(manifest) do
    properties = manifest[:properties] || %{}

    if map_size(properties) == 0 do
      ""
    else
      properties
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map_join("\n", fn {name, %{syntax: syntax, initial: initial}} ->
        """
        @property #{name} {
          syntax: '#{syntax}';
          inherits: true;
          initial-value: #{initial};
        }
        """
      end)
    end
  end

  defp get_vars_css(manifest) do
    vars = manifest[:vars] || %{}

    if map_size(vars) == 0 do
      ""
    else
      declarations =
        vars
        |> Enum.sort_by(fn {name, _} -> name end)
        |> Enum.map_join("\n", fn {name, value} ->
          format_var_declaration(name, value)
        end)

      ":root {\n#{declarations}\n}\n"
    end
  end

  defp format_var_declaration(name, value) when is_binary(value) do
    "  #{name}: #{value};"
  end

  defp format_var_declaration(name, value) when is_map(value) do
    default = Map.get(value, "default") || Map.get(value, :default)

    if default do
      "  #{name}: #{default};"
    else
      first_value = value |> Map.values() |> List.first()
      "  #{name}: #{first_value};"
    end
  end

  defp get_keyframes_css(manifest) do
    keyframes = manifest[:keyframes] || %{}

    if map_size(keyframes) == 0 do
      ""
    else
      keyframes
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map_join("\n\n", fn {_name, css} -> css end)
      |> Kernel.<>("\n")
    end
  end

  defp get_view_transitions_css(manifest) do
    vt_css = manifest[:view_transition_css] || []

    if Enum.empty?(vt_css) do
      ""
    else
      vt_css
      |> Enum.reverse()
      |> Enum.join("\n")
    end
  end

  defp get_rules_css(manifest) do
    rules = manifest[:rules] || %{}

    if map_size(rules) == 0 do
      ""
    else
      rule_list =
        rules
        |> Enum.sort_by(fn {_class, {_css, priority}} -> priority end)
        |> Enum.map_join("\n  ", fn {_class, {css, _priority}} -> css end)

      """
      @layer live_style {
        #{rule_list}
      }
      """
    end
  end

  @doc """
  Clears the manifest file.
  """
  @spec clear() :: :ok
  def clear do
    File.rm(manifest_path())
    :ok
  end

  @doc false
  def record_var_usage(css_var_name, original_name, file, line) do
    update_manifest(fn manifest ->
      usages = manifest[:var_usages] || %{}
      updated_usages = Map.put_new(usages, css_var_name, {original_name, file, line})
      Map.put(manifest, :var_usages, updated_usages)
    end)
  end

  @doc false
  def store_module_style(module, style_name, declarations) do
    update_manifest(fn manifest ->
      module_styles = manifest[:module_styles] || %{}
      styles_for_module = Map.get(module_styles, module, %{})
      updated_styles = Map.put(styles_for_module, style_name, declarations)
      Map.put(manifest, :module_styles, Map.put(module_styles, module, updated_styles))
    end)
  end

  @doc false
  def get_module_styles(module) do
    manifest = read_manifest()
    module_styles = manifest[:module_styles] || %{}
    Map.get(module_styles, module, %{})
  end

  @doc """
  Validates that all var() usages reference defined variables.

  This is called by the LiveStyle compiler after all modules are compiled.
  Checks both:
  1. Direct var() usages in styles
  2. var() references within defvars definitions

  Returns `:ok` if all references are valid, or raises with details about undefined references.
  """
  @spec validate_var_references!() :: :ok
  def validate_var_references! do
    manifest = read_manifest()
    vars = manifest[:vars] || %{}
    usages = manifest[:var_usages] || %{}

    errors = []

    undefined_usages =
      usages
      |> Enum.reject(fn {css_var_name, _location} -> Map.has_key?(vars, css_var_name) end)
      |> Enum.map(fn {css_var_name, {original_name, file, line}} ->
        name_str = Atom.to_string(original_name)

        {namespace, var_name} =
          case String.split(name_str, "_", parts: 2) do
            [ns, rest] -> {ns, rest}
            [single] -> {"vars", single}
          end

        """
          * var(:#{original_name}) at #{Path.relative_to_cwd(file)}:#{line}
            Variable #{css_var_name} is not defined.
            
            To fix, add to your tokens module:
            
                defvars(:#{namespace}, %{
                  #{var_name}: "value"
                })
        """
      end)

    errors = errors ++ undefined_usages

    undefined_refs =
      vars
      |> Enum.filter(fn {_key, value} ->
        case extract_var_reference(value) do
          nil -> false
          ref_var -> not Map.has_key?(vars, ref_var)
        end
      end)
      |> Enum.map(fn {var_name, value} ->
        ref_var = extract_var_reference(value)

        """
          * #{var_name} references undefined #{ref_var}
            Check your defvars definitions - the referenced variable must be defined.
        """
      end)

    errors = errors ++ undefined_refs

    if Enum.empty?(errors) do
      :ok
    else
      error_text = Enum.join(errors, "\n")

      raise CompileError,
        description: """
        LiveStyle: Found undefined CSS variable references:

        #{error_text}
        """
    end
  end

  defp extract_var_reference(value) when is_binary(value) do
    case Regex.run(~r/^var\((--[a-zA-Z0-9_-]+)\)$/, value) do
      [_, var_name] -> var_name
      _ -> nil
    end
  end

  defp extract_var_reference(_), do: nil

  @doc """
  Resolves __include__ entries in a style declarations map.

  This function is called at compile time during style/2 macro expansion.
  It finds the `__include__: [...]` entry and replaces it with the actual
  style declarations from the referenced sources.

  Include entries can be:
  - `{Module, :style_name}` - include from another module
  - `:style_name` - include from the same module (self-reference)

  The includes are processed in order, then remaining declarations are merged
  on top, giving later declarations precedence (last-wins semantics).
  """
  @spec resolve_includes(map(), map(), atom() | nil) :: map()
  def resolve_includes(declarations, local_styles \\ %{}, caller_module \\ nil)
      when is_map(declarations) do
    {includes_list, regular} = Map.pop(declarations, :__include__, [])

    base =
      includes_list
      |> Enum.reduce(%{}, fn include_ref, acc ->
        included = fetch_included_style(include_ref, local_styles, caller_module)
        Map.merge(acc, included)
      end)

    Map.merge(base, regular)
  end

  defp fetch_included_style({module, style_name}, _local_styles, _caller_module)
       when is_atom(module) do
    fetch_external_style(module, style_name)
  end

  defp fetch_included_style(style_name, local_styles, caller_module) when is_atom(style_name) do
    case Map.fetch(local_styles, style_name) do
      {:ok, declarations} ->
        # Recursively resolve includes in the included style
        resolve_includes(declarations, local_styles, caller_module)

      :error ->
        raise CompileError,
          description: """
          LiveStyle: Cannot include :#{style_name} - style not found.

          Self-references must refer to styles defined earlier in the same module.
          Make sure :#{style_name} is defined before it's included.

          Available local styles: #{inspect(Map.keys(local_styles))}
          """
    end
  end

  defp fetch_external_style(module, style_name) do
    Code.ensure_loaded!(module)

    unless function_exported?(module, :__live_style__, 1) do
      raise CompileError,
        description: """
        LiveStyle: Cannot include styles from #{inspect(module)}.

        The module must use LiveStyle and define styles with the style/2 macro.
        Make sure #{inspect(module)} is compiled before this module.
        """
    end

    case module.__live_style__(style_name) do
      nil ->
        raise CompileError,
          description: """
          LiveStyle: Style :#{style_name} not found in #{inspect(module)}.

          Available styles: #{inspect(get_available_styles(module))}
          """

      declarations ->
        declarations
    end
  end

  defp get_available_styles(module) do
    if function_exported?(module, :__live_style__, 1) do
      "(check the module definition)"
    else
      "(none - module doesn't use LiveStyle)"
    end
  end

  @doc false
  def process_style_map(declarations, keyframes_map) when is_map(declarations) do
    declarations
    |> Enum.flat_map(fn {key, value} ->
      process_style_entry(key, value, keyframes_map)
    end)
    |> Map.new()
  end

  defp process_pseudo_element(pseudo_element, style_map, keyframes_map) do
    Enum.flat_map(style_map, fn {prop, value} ->
      process_property_with_conditions(prop, value, keyframes_map, pseudo_element, nil)
    end)
  end

  @doc false
  def generate_var_name(namespace, name) do
    input = "#{namespace}:#{name}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "--v#{hash}"
  end

  @doc false
  def generate_keyframe_name(name, module) do
    input = "#{module}:#{name}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "k#{hash}"
  end

  @doc false
  def register_keyframes(keyframe_name, frames) do
    css = build_keyframes_css(keyframe_name, frames)

    update_manifest(fn manifest ->
      keyframes = manifest[:keyframes] || %{}

      if Map.has_key?(keyframes, keyframe_name) do
        manifest
      else
        Map.put(manifest, :keyframes, Map.put(keyframes, keyframe_name, css))
      end
    end)

    :ok
  end

  @doc false
  def register_rule(class_name, css_rule, priority) do
    update_manifest(fn manifest ->
      rules = manifest[:rules] || %{}

      if Map.has_key?(rules, class_name) do
        manifest
      else
        Map.put(manifest, :rules, Map.put(rules, class_name, {css_rule, priority}))
      end
    end)

    :ok
  end

  defp process_style_entry(key, value, keyframes_map) do
    key_str = to_string(key)

    # Pseudo-elements (::before, ::after, etc.) - value is a map of properties
    if String.starts_with?(key_str, "::") do
      process_pseudo_element(key_str, value, keyframes_map)
    else
      # Regular CSS property (possibly with conditional values)
      process_property_with_conditions(key, value, keyframes_map, nil, nil)
    end
  end

  defp process_property_with_conditions(
         key,
         %{__first_that_works__: true} = value,
         keyframes_map,
         pseudo_element,
         _parent_condition
       ) do
    generate_rule(key, value, keyframes_map, pseudo_element, nil, nil)
  end

  defp process_property_with_conditions(
         key,
         value,
         keyframes_map,
         pseudo_element,
         parent_pseudo_class
       )
       when is_map(value) do
    Enum.flat_map(value, fn {condition, cond_value} ->
      process_condition(
        key,
        condition,
        cond_value,
        keyframes_map,
        pseudo_element,
        parent_pseudo_class
      )
    end)
  end

  defp process_property_with_conditions(
         key,
         value,
         keyframes_map,
         pseudo_element,
         _parent_condition
       ) do
    generate_rule(key, value, keyframes_map, pseudo_element, nil, nil)
  end

  defp process_condition(
         key,
         condition,
         cond_value,
         keyframes_map,
         pseudo_element,
         parent_pseudo_class
       ) do
    condition_str = to_string(condition)

    cond do
      condition == :default or condition_str == "default" ->
        generate_rule(key, cond_value, keyframes_map, pseudo_element, parent_pseudo_class, nil)

      pseudo_class?(condition_str) ->
        process_pseudo_class_condition(
          key,
          condition_str,
          cond_value,
          keyframes_map,
          pseudo_element,
          parent_pseudo_class
        )

      String.starts_with?(condition_str, "@") ->
        generate_rule(
          key,
          cond_value,
          keyframes_map,
          pseudo_element,
          parent_pseudo_class,
          condition_str
        )

      true ->
        []
    end
  end

  defp pseudo_class?(str),
    do: String.starts_with?(str, ":") and not String.starts_with?(str, "::")

  defp process_pseudo_class_condition(
         key,
         condition_str,
         cond_value,
         keyframes_map,
         pseudo_element,
         parent_pseudo_class
       ) do
    combined_pseudo = combine_pseudo_classes(parent_pseudo_class, condition_str)

    if nested_condition_map?(cond_value) do
      process_property_with_conditions(
        key,
        cond_value,
        keyframes_map,
        pseudo_element,
        combined_pseudo
      )
    else
      generate_rule(key, cond_value, keyframes_map, pseudo_element, combined_pseudo, nil)
    end
  end

  defp combine_pseudo_classes(nil, condition_str), do: condition_str
  defp combine_pseudo_classes(parent, condition_str), do: "#{parent}#{condition_str}"

  defp nested_condition_map?(value) do
    is_map(value) and not Map.has_key?(value, :__first_that_works__)
  end

  defp generate_rule(key, value, keyframes_map, pseudo_element, pseudo_class, at_rule) do
    css_property = to_css_property(key)

    case value do
      %{__first_that_works__: true, values: values} ->
        generate_fallback_rule(key, css_property, values, pseudo_element, pseudo_class, at_rule)

      value when is_atom(value) ->
        css_value =
          case Map.fetch(keyframes_map, value) do
            {:ok, kf_name} -> kf_name
            :error -> to_string(value)
          end

        generate_simple_rule(key, css_property, css_value, pseudo_element, pseudo_class, at_rule)

      _ ->
        css_value = to_css_value(value)
        generate_simple_rule(key, css_property, css_value, pseudo_element, pseudo_class, at_rule)
    end
  end

  defp generate_fallback_rule(key, css_property, values, pseudo_element, pseudo_class, at_rule) do
    selector_suffix = build_selector_suffix(pseudo_element, pseudo_class)
    values_str = Enum.join(values, "|")
    class_name = generate_class_name(css_property, values_str, selector_suffix, at_rule)

    declarations =
      values
      |> Enum.reverse()
      |> Enum.map_join(" ", fn v -> "#{css_property}: #{to_css_value(v)};" end)

    css_rule =
      build_css_rule_with_declarations(class_name, declarations, selector_suffix, at_rule)

    priority = get_property_priority(css_property, pseudo_class, at_rule)
    register_rule(class_name, css_rule, priority)
    atomic_key = build_atomic_key(key, pseudo_element, pseudo_class, at_rule)
    [{atomic_key, class_name}]
  end

  defp generate_simple_rule(key, css_property, css_value, pseudo_element, pseudo_class, at_rule) do
    selector_suffix = build_selector_suffix(pseudo_element, pseudo_class)
    class_name = generate_class_name(css_property, css_value, selector_suffix, at_rule)
    css_rule = build_css_rule(class_name, css_property, css_value, selector_suffix, at_rule)
    priority = get_property_priority(css_property, pseudo_class, at_rule)
    register_rule(class_name, css_rule, priority)
    atomic_key = build_atomic_key(key, pseudo_element, pseudo_class, at_rule)
    [{atomic_key, class_name}]
  end

  defp build_selector_suffix(nil, nil), do: nil
  defp build_selector_suffix(pseudo_element, nil), do: pseudo_element
  defp build_selector_suffix(nil, pseudo_class), do: pseudo_class
  defp build_selector_suffix(pseudo_element, pseudo_class), do: "#{pseudo_element}#{pseudo_class}"

  defp build_css_rule(class_name, property, value, nil, nil) do
    ".#{class_name} { #{property}: #{value}; }"
  end

  defp build_css_rule(class_name, property, value, selector_suffix, nil) do
    ".#{class_name}#{selector_suffix} { #{property}: #{value}; }"
  end

  defp build_css_rule(class_name, property, value, nil, at_rule) do
    "#{at_rule} { .#{class_name} { #{property}: #{value}; } }"
  end

  defp build_css_rule(class_name, property, value, selector_suffix, at_rule) do
    "#{at_rule} { .#{class_name}#{selector_suffix} { #{property}: #{value}; } }"
  end

  defp build_css_rule_with_declarations(class_name, declarations, nil, nil) do
    ".#{class_name} { #{declarations} }"
  end

  defp build_css_rule_with_declarations(class_name, declarations, selector_suffix, nil) do
    ".#{class_name}#{selector_suffix} { #{declarations} }"
  end

  defp build_css_rule_with_declarations(class_name, declarations, nil, at_rule) do
    "#{at_rule} { .#{class_name} { #{declarations} } }"
  end

  defp build_css_rule_with_declarations(class_name, declarations, selector_suffix, at_rule) do
    "#{at_rule} { .#{class_name}#{selector_suffix} { #{declarations} } }"
  end

  defp build_atomic_key(key, nil, nil, nil), do: key

  defp build_atomic_key(key, pseudo_element, pseudo_class, at_rule) do
    suffix =
      [pseudo_element, pseudo_class, at_rule]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("")

    String.to_atom("#{key}#{suffix}")
  end

  defp build_keyframes_css(name, frames) do
    frame_rules =
      Enum.map_join(frames, "\n", fn {selector, properties} ->
        css_selector = normalize_keyframe_selector(selector)

        css_properties =
          Enum.map_join(properties, " ", fn {prop, value} ->
            css_prop = to_css_property_for_keyframes(prop)
            "#{css_prop}: #{to_css_value(value)};"
          end)

        "  #{css_selector} { #{css_properties} }"
      end)

    "@keyframes #{name} {\n#{frame_rules}\n}"
  end

  defp to_css_property_for_keyframes(prop) when is_binary(prop) do
    cond do
      String.starts_with?(prop, "var(") and String.ends_with?(prop, ")") ->
        String.slice(prop, 4..-2//1)

      String.starts_with?(prop, "--") ->
        prop

      true ->
        String.replace(prop, "_", "-")
    end
  end

  defp to_css_property_for_keyframes(prop) when is_atom(prop) do
    prop |> Atom.to_string() |> to_css_property_for_keyframes()
  end

  defp normalize_keyframe_selector(:from), do: "from"
  defp normalize_keyframe_selector(:to), do: "to"
  defp normalize_keyframe_selector(selector) when is_atom(selector), do: Atom.to_string(selector)
  defp normalize_keyframe_selector(selector) when is_binary(selector), do: selector

  defp generate_class_name(property, value, selector_suffix, at_rule) do
    input = "#{property}:#{value}:#{selector_suffix || ""}:#{at_rule || ""}"

    hash =
      :crypto.hash(:md5, input)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    "x#{hash}"
  end

  defp get_property_priority(property, pseudo_class, at_rule) do
    base = Map.get(@property_priority, property, 9999)
    pseudo_mod = if pseudo_class, do: 10_000, else: 0
    at_rule_mod = if at_rule, do: 20_000, else: 0
    base + pseudo_mod + at_rule_mod
  end

  defp to_css_property(key) when is_atom(key) do
    key |> Atom.to_string() |> String.replace("_", "-")
  end

  defp to_css_property(key), do: to_string(key)

  defp to_css_value(v) when is_binary(v), do: v
  defp to_css_value(v) when is_number(v), do: to_string(v)
  defp to_css_value(v) when is_atom(v), do: Atom.to_string(v)
end
