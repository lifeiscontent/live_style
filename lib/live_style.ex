defmodule LiveStyle do
  @moduledoc """
  LiveStyle - Compile-time CSS-in-Elixir for Phoenix LiveView.

  All style definitions compile away to string constants. At runtime,
  only class name strings exist - no function calls or manifest lookups.

  ## Recommended Usage

  Use the specialized modules for clearer intent:

  - **`use LiveStyle.Tokens`** - For design tokens (CSS variables, keyframes, themes)
  - **`use LiveStyle.Sheet`** - For component styles (css_class definitions)

  See `LiveStyle.Tokens` and `LiveStyle.Sheet` for detailed documentation.

  ### Tokens Module

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_vars :color,
          white: "#ffffff",
          primary: "#3b82f6"

        css_keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]
      end

  ### Component with Styles

      defmodule MyApp.Button do
        use Phoenix.Component
        use LiveStyle.Sheet

        css_class :base,
          display: "inline-flex",
          padding: "0.5rem 1rem"

        css_class :primary,
          background_color: css_var({MyApp.Tokens, :color, :primary})

        def render(assigns) do
          ~H\"\"\"
          <button class={css_class([:base, :primary])}>
            <%= render_slot(@inner_block) %>
          </button>
          \"\"\"
        end
      end

  ## Reference Syntax

  Cross-module references:
  - `css_var({Module, :namespace, :name})` - Reference a CSS variable
  - `css_const({Module, :namespace, :name})` - Reference a compile-time constant
  - `css_keyframes({Module, :name})` - Reference a keyframes animation
  - `css_theme({Module, :namespace, :theme_name})` - Reference a theme class
  - `css_position_try({Module, :name})` - Reference a position-try rule
  - `css_view_transition({Module, :name})` - Reference a view transition

  Local references (within the same module):
  - `css_var({:namespace, :name})`
  - `css_keyframes(:name)`
  - `css_theme({:namespace, :theme_name})`

  ## Public API Functions

  For accessing styles from outside a module (e.g., in tests):
  - `LiveStyle.get_css/2` - Get `%LiveStyle.Attrs{}` from a module's classes
  - `LiveStyle.get_css_class/2` - Get class string from a module's classes
  - `LiveStyle.default_marker/0` - Get the default marker class for contextual selectors
  - `LiveStyle.define_marker/1` - Create a custom marker class

  See the README for comprehensive documentation and examples.
  """

  alias LiveStyle.Manifest

  defmacro __using__(_opts \\ []) do
    quote do
      import LiveStyle,
        only: [
          # Definition macros
          css_vars: 2,
          css_consts: 2,
          css_keyframes: 2,
          css_position_try: 2,
          css_view_transition: 2,
          css_class: 2,
          css_theme: 3,
          # Reference macros
          css_var: 1,
          css_const: 1,
          css_keyframes: 1,
          css_position_try: 1,
          css_view_transition: 1,
          css_theme: 1,
          # Utilities
          first_that_works: 1
        ]

      # Accumulate class definitions for @before_compile
      Module.register_attribute(__MODULE__, :__live_style_classes__, accumulate: true)

      @before_compile LiveStyle
    end
  end

  defmacro __before_compile__(env) do
    classes = Module.get_attribute(env.module, :__live_style_classes__) |> Enum.reverse()

    # Separate static from dynamic classes
    # Dynamic classes have format: {:__dynamic__, all_props, param_names, has_computed}
    {static_classes, dynamic_classes} =
      Enum.split_with(classes, fn {_name, decl} ->
        not match?({:__dynamic__, _, _, _}, decl)
      end)

    # Build class string map and property_classes map for static classes
    {class_strings, property_classes} = build_static_class_maps(static_classes, env.module)

    # Generate dynamic class functions
    # Dynamic classes: {name, {:__dynamic__, all_props, param_names, has_computed}}
    dynamic_fns = build_dynamic_fns(dynamic_classes, env.module)

    dynamic_names = Enum.map(dynamic_classes, fn {name, _} -> name end)

    quote do
      @__class_strings__ unquote(Macro.escape(class_strings))
      @__property_classes__ unquote(Macro.escape(property_classes))
      @__dynamic_names__ unquote(dynamic_names)

      unquote_splicing(dynamic_fns)

      @doc false
      def __live_style__(:class_strings), do: @__class_strings__
      def __live_style__(:property_classes), do: @__property_classes__
      def __live_style__(:dynamic_names), do: @__dynamic_names__

      # css_class/1 - returns just the class string for use with class={...}
      # Private to avoid conflicts when importing other LiveStyle modules
      @doc false
      defp css_class(refs) when is_list(refs) do
        LiveStyle.resolve_class_string(__MODULE__, refs, @__class_strings__)
      end

      @doc false
      defp css_class(ref) when is_atom(ref) do
        Map.get(@__class_strings__, ref, "")
      end

      # css/1 - returns %Attrs{} for spreading with {css(...)}
      # Private to avoid conflicts when importing other LiveStyle modules
      @doc false
      defp css(refs) when is_list(refs) do
        LiveStyle.resolve_attrs(__MODULE__, refs, @__class_strings__)
      end

      @doc false
      defp css(ref) when is_atom(ref) do
        %LiveStyle.Attrs{class: Map.get(@__class_strings__, ref, ""), style: nil}
      end
    end
  end

  @doc """
  Defines CSS custom properties (variables) under a namespace.

  ## Examples

      css_vars :color,
        white: "#ffffff",
        primary: "#3b82f6"

      css_vars :space,
        sm: "0.5rem",
        lg: "2rem"

  For typed variables that can be animated, use `LiveStyle.Types`:

      import LiveStyle.Types

      css_vars :anim,
        angle: angle("0deg"),
        hue: percentage("0%")
  """
  defmacro css_vars(namespace, vars) when is_atom(namespace) do
    # Evaluate vars at compile time so they're available for css_var references
    {evaluated_vars, _} = Code.eval_quoted(vars, [], __CALLER__)
    module = __CALLER__.module

    # Store immediately during macro expansion (like css_consts does)
    # so that css_var/1 references in the same module can find them
    LiveStyle.Vars.define(module, namespace, evaluated_vars)

    quote do
      :ok
    end
  end

  @doc """
  References a CSS variable, returning `var(--vhash)`.

  When used as a value, returns `var(--vhash)` for CSS variable references.
  When used as a map key in keyframes, the `var()` wrapper is automatically
  stripped to produce valid CSS (matching StyleX behavior).

  ## Local reference (same module)

      css_var({:color, :white})

  ## Cross-module reference

      css_var({MyApp.Tokens, :color, :white})

  ## Using in keyframes (animating typed variables)

      css_keyframes :rotate,
        from: %{css_var({Tokens, :anim, :angle}) => "0deg"},
        to: %{css_var({Tokens, :anim, :angle}) => "360deg"}
  """
  defmacro css_var(ref) do
    case ref do
      {:{}, _, [module_ast, namespace, name]} ->
        # Cross-module: {Module, :namespace, :name}
        {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
        LiveStyle.Vars.lookup!(module, namespace, name)

      {namespace, name} when is_atom(namespace) and is_atom(name) ->
        # Local reference: {:namespace, :name}
        module = __CALLER__.module
        LiveStyle.Vars.lookup!(module, namespace, name)
    end
  end

  @doc """
  Defines compile-time constants (no CSS output).

  ## Examples

      css_consts :breakpoint,
        sm: "@media (max-width: 640px)",
        lg: "@media (min-width: 1025px)"

      css_consts :z,
        modal: "50",
        tooltip: "100"
  """
  defmacro css_consts(namespace, consts) when is_atom(namespace) do
    # Evaluate consts at compile time so they're available for css_const references
    {evaluated_consts, _} = Code.eval_quoted(consts, [], __CALLER__)
    module = __CALLER__.module

    # Store immediately during macro expansion (like css_keyframes does)
    # so that css_const/1 references in the same module can find them
    LiveStyle.Consts.define(module, namespace, evaluated_consts)

    quote do
      :ok
    end
  end

  @doc """
  References a constant, returning its raw value.

  ## Local reference

      css_const({:breakpoint, :lg})

  ## Cross-module reference

      css_const({MyApp.Tokens, :breakpoint, :lg})

  Note: Requires the defining module to be compiled first.
  """
  defmacro css_const(ref) do
    case ref do
      {:{}, _, [module_ast, namespace, name]} ->
        # Cross-module: {Module, :namespace, :name}
        {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
        LiveStyle.Consts.lookup!(module, namespace, name)

      {namespace, name} when is_atom(namespace) and is_atom(name) ->
        # Local reference: {:namespace, :name}
        module = __CALLER__.module
        LiveStyle.Consts.lookup!(module, namespace, name)
    end
  end

  @doc """
  Defines a keyframes animation (2-arg form) or references one (1-arg form).

  ## Definition (2 args)

      css_keyframes :spin,
        from: [transform: "rotate(0deg)"],
        to: [transform: "rotate(360deg)"]

      css_keyframes :fade_in,
        "0%": [opacity: "0"],
        "100%": [opacity: "1"]

  ## Local reference (1 arg)

      css_keyframes(:spin)

  ## Cross-module reference

      css_keyframes({MyApp.Tokens, :spin})
  """
  defmacro css_keyframes(name, frames) when is_atom(name) do
    {evaluated_frames, _} = Code.eval_quoted(frames, [], __CALLER__)
    module = __CALLER__.module

    # Define keyframes and store in manifest
    LiveStyle.Keyframes.define(module, name, evaluated_frames)

    quote do
      :ok
    end
  end

  defmacro css_keyframes(ref) when is_atom(ref) do
    module = __CALLER__.module
    LiveStyle.Keyframes.lookup!(module, ref)
  end

  defmacro css_keyframes({module_ast, name}) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.Keyframes.lookup!(module, name)
  end

  @doc """
  Defines or references a @position-try rule for anchor positioning.

  ## Definition (2 args)

      css_position_try :bottom_fallback,
        top: "anchor(bottom)",
        left: "anchor(left)"

  ## Local reference (1 arg atom)

      css_position_try(:bottom_fallback)

  ## Cross-module reference (1 arg tuple)

      css_position_try({MyApp.Tokens, :bottom_fallback})
  """
  defmacro css_position_try(name, declarations) when is_atom(name) do
    # Evaluate declarations at compile time for content-based hashing (StyleX behavior)
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = normalize_to_map(evaluated)

    # Normalize values (add px to numbers, etc.)
    normalized_values =
      normalized
      |> Enum.map(fn {k, v} -> {k, LiveStyle.PositionTry.normalize_value(v)} end)
      |> Map.new()

    # Generate CSS string for hashing (StyleX format: sorted keys, "key:value;" no spaces)
    css_name = LiveStyle.PositionTry.generate_css_name(normalized_values)

    quote do
      LiveStyle.PositionTry.define(
        __MODULE__,
        unquote(name),
        unquote(Macro.escape(normalized_values)),
        unquote(css_name)
      )
    end
  end

  defmacro css_position_try(ref) when is_atom(ref) do
    module = __CALLER__.module
    LiveStyle.PositionTry.lookup!(module, ref)
  end

  defmacro css_position_try({module_ast, name}) when is_atom(name) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.PositionTry.lookup!(module, name)
  end

  # Inline anonymous position-try: css_position_try(top: "0", left: "0")
  # Returns a content-hashed dashed-ident name (like StyleX positionTry)
  defmacro css_position_try(declarations) when is_list(declarations) do
    module = __CALLER__.module
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = normalize_to_map(evaluated)

    # Validate and normalize declarations
    case LiveStyle.PositionTry.validate_declarations(normalized) do
      {:ok, normalized_values} ->
        css_name = LiveStyle.PositionTry.generate_css_name(normalized_values)
        LiveStyle.PositionTry.define_anonymous(module, normalized_values, css_name)
        css_name

      {:error, invalid_props} ->
        allowed = LiveStyle.PositionTry.allowed_properties()

        raise ArgumentError, """
        Invalid properties in css_position_try: #{inspect(invalid_props)}

        Only these properties are allowed in @position-try rules:
        #{Enum.join(allowed, ", ")}
        """
    end
  end

  @doc """
  Defines a view transition class.

  ## Examples

      css_view_transition :card_transition,
        old: [animation_name: css_keyframes(:fade_out), animation_duration: "250ms"],
        new: [animation_name: css_keyframes(:fade_in), animation_duration: "250ms"]
  """
  defmacro css_view_transition(name, styles) when is_atom(name) do
    # Evaluate styles at compile time to resolve keyframes references
    {evaluated_styles, _} = Code.eval_quoted(styles, [], __CALLER__)

    # Validate keys at compile time
    style_map = normalize_to_map(evaluated_styles)

    case LiveStyle.ViewTransition.validate_keys(style_map) do
      :ok ->
        :ok

      {:error, invalid_keys} ->
        raise ArgumentError,
              "Invalid view transition key: #{inspect(invalid_keys)}. " <>
                "Valid keys are: #{inspect(LiveStyle.ViewTransition.valid_atom_keys())} (atoms) " <>
                "or #{inspect(LiveStyle.ViewTransition.valid_string_keys())} (strings)"
    end

    # Generate CSS content string for content-based hashing (StyleX-compatible)
    css_name = LiveStyle.ViewTransition.generate_css_name(evaluated_styles)

    quote do
      LiveStyle.ViewTransition.define(
        __MODULE__,
        unquote(name),
        unquote(Macro.escape(evaluated_styles)),
        unquote(css_name)
      )
    end
  end

  @doc """
  References a view transition, returning the class name.

  ## Local reference

      css_view_transition(:card_transition)

  ## Cross-module reference

      css_view_transition({MyApp.Components.Card, :card_transition})
  """
  defmacro css_view_transition(ref) when is_atom(ref) do
    quote do
      LiveStyle.ViewTransition.get_name(__MODULE__, unquote(ref))
    end
  end

  defmacro css_view_transition({module_ast, name}) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    quote do
      LiveStyle.ViewTransition.get_name(unquote(module), unquote(name))
    end
  end

  @doc """
  Defines a style class with CSS declarations.

  ## Static classes

      css_class :button,
        display: "flex",
        padding: "8px 16px"

  ## With variable references

      css_class :themed,
        color: css_var({MyApp.Tokens, :color, :white})

  ## Dynamic classes (StyleX-style with CSS variables)

  Dynamic classes use a function that declares which properties can be set at runtime.
  The CSS is generated with `var(--x-property)` references, and at runtime only
  the CSS variable values are set via inline style.

      # Single parameter
      css_class :dynamic_opacity, fn opacity -> [opacity: opacity] end
      
      # Multiple parameters  
      css_class :dynamic_size, fn width, height -> [width: width, height: height] end

  Usage:
      <div {css([:base, {:dynamic_opacity, "0.5"}])}>
      <div {css([:base, {:dynamic_size, ["100px", "200px"]}])}>
  """
  defmacro css_class(name, declarations) when is_atom(name) and is_list(declarations) do
    # Static class - keyword list of declarations
    # Defer evaluation to runtime within the module to access module attributes
    module = __CALLER__.module

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.normalize_to_map(declarations_evaluated)

      LiveStyle.Class.define(
        unquote(module),
        unquote(name),
        normalized
      )

      @__live_style_classes__ {unquote(name), normalized}
    end
  end

  # Static class with map syntax - css_class(:name, %{...})
  defmacro css_class(name, {:%{}, _, _} = declarations) when is_atom(name) do
    module = __CALLER__.module

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.normalize_to_map(declarations_evaluated)

      LiveStyle.Class.define(
        unquote(module),
        unquote(name),
        normalized
      )

      @__live_style_classes__ {unquote(name), normalized}
    end
  end

  # Dynamic class - function that returns declarations
  # css_class :dynamic_opacity, fn opacity -> [opacity: opacity] end
  defmacro css_class(name, {:fn, _, [{:->, _, [params, body]}]} = func) when is_atom(name) do
    module = __CALLER__.module

    # Extract parameter names from the function
    param_names = extract_param_names(params)

    # Evaluate the function body to get the declarations
    expanded_body = Macro.expand(body, __CALLER__)

    # The body should be a keyword list like [opacity: opacity]
    # We extract the property names from it
    declarations = extract_declarations(expanded_body, param_names)

    # Get ALL property names (both simple bindings and computed)
    all_props = Enum.map(declarations, fn {prop, _} -> prop end)

    # Check if any property has computed values (complex expressions)
    has_computed = Enum.any?(declarations, fn {_, binding} -> binding == :computed end)

    # Generate a compute function name
    compute_fn_name = :"__compute_#{name}__"

    quote do
      LiveStyle.Class.define_dynamic(
        unquote(module),
        unquote(name),
        unquote(Macro.escape(all_props)),
        unquote(param_names)
      )

      # Generate a function that computes the declarations at runtime
      # This function calls the original lambda with the provided values
      @doc false
      def unquote(compute_fn_name)(values) do
        func = unquote(func)
        apply(func, values)
      end

      @__live_style_classes__ {unquote(name),
                               {:__dynamic__, unquote(Macro.escape(all_props)),
                                unquote(param_names), unquote(has_computed)}}
    end
  end

  defp extract_param_names(params) do
    Enum.map(params, fn
      {name, _, _} when is_atom(name) -> name
      _ -> raise ArgumentError, "Dynamic rule parameters must be simple identifiers"
    end)
  end

  defp extract_declarations([{_key, _val} | _] = kw, param_names) when is_list(kw) do
    Enum.map(kw, fn entry -> extract_declaration_entry(entry, param_names) end)
  end

  defp extract_declarations(expanded_body, _param_names) do
    raise ArgumentError,
          "Dynamic rule body must be a keyword list, got: #{inspect(expanded_body)}"
  end

  defp extract_declaration_entry({prop, {param_name, _, _}}, param_names)
       when is_atom(param_name) do
    # Check if this is a simple variable reference (not a special form like :<<>>)
    if simple_var_in_params?(param_name, param_names) do
      {prop, param_name}
    else
      # Special form or not a declared param - treat as computed
      {prop, :computed}
    end
  end

  defp extract_declaration_entry({prop, _value}, _param_names) do
    # Complex expression (e.g., string interpolation) - mark as :computed
    # The value will be computed at runtime by calling the actual function
    {prop, :computed}
  end

  defp simple_var_in_params?(param_name, param_names) do
    param_str = Atom.to_string(param_name)
    is_simple_var = param_str =~ ~r/^[a-z_][a-zA-Z0-9_]*$/
    is_simple_var and param_name in param_names
  end

  @doc """
  References a style class, returning the class string.

  ## Local reference

      css_class(:button)

  ## Cross-module reference

      css_class({MyApp.Button, :button})
  """
  defmacro css_class({module, name}) do
    key = Manifest.simple_key(module, name)

    quote do
      manifest = LiveStyle.Storage.read()

      case LiveStyle.Manifest.get_class(manifest, unquote(key)) do
        nil ->
          raise ArgumentError, "Unknown class: #{unquote(key)}"

        %{class_string: cs} ->
          cs
      end
    end
  end

  defmacro css_class(name) when is_atom(name) do
    quote do
      Map.get(@__class_strings__, unquote(name), "")
    end
  end

  @doc """
  Defines a theme (variable overrides) for a specific var group.

  Similar to StyleX's `createTheme`, this creates overrides scoped to a 
  specific var group defined with `css_vars`.

  ## Examples

      # First define your variables
      css_vars :color,
        white: "#ffffff",
        primary: "#3b82f6"

      # Then create a theme that overrides those variables
      css_theme :color, :dark,
        white: "#000000",
        primary: "#8ab4f8"

      # Cross-module theme (override vars from another module)
      css_theme {OtherModule, :color}, :dark,
        white: "#000000"
  """
  defmacro css_theme(var_group_ref, theme_name, overrides)
           when is_atom(var_group_ref) and is_atom(theme_name) do
    # Local var group reference
    module = __CALLER__.module
    namespace = var_group_ref
    css_name = LiveStyle.Theme.generate_css_name(module, namespace, theme_name)

    quote do
      LiveStyle.Theme.define(
        unquote(module),
        unquote(namespace),
        unquote(theme_name),
        unquote(overrides),
        unquote(css_name)
      )
    end
  end

  defmacro css_theme({var_group_module_ast, var_group_namespace}, theme_name, overrides)
           when is_atom(theme_name) do
    # Cross-module var group reference: {Module, :namespace}
    {var_group_module, _} = Code.eval_quoted(var_group_module_ast, [], __CALLER__)
    theme_module = __CALLER__.module
    css_name = LiveStyle.Theme.generate_css_name(theme_module, var_group_namespace, theme_name)

    quote do
      LiveStyle.Theme.define(
        unquote(var_group_module),
        unquote(var_group_namespace),
        unquote(theme_name),
        unquote(overrides),
        unquote(css_name),
        unquote(theme_module)
      )
    end
  end

  @doc """
  References a theme, returning the class name.

  ## Local reference

      css_theme({:color, :dark})

  ## Cross-module reference

      css_theme({MyApp.Tokens, :color, :dark})
  """
  defmacro css_theme(ref) do
    case ref do
      {:{}, _, [module_ast, namespace, theme_name]} ->
        # Cross-module: {Module, :namespace, :theme_name}
        {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
        LiveStyle.Theme.generate_css_name(module, namespace, theme_name)

      {namespace, theme_name} when is_atom(namespace) and is_atom(theme_name) ->
        # Local reference: {:namespace, :theme_name}
        module = __CALLER__.module
        LiveStyle.Theme.generate_css_name(module, namespace, theme_name)
    end
  end

  @doc """
  Creates fallback values for CSS properties (StyleX `firstThatWorks` equivalent).

  This function handles two cases:

  1. **Regular fallbacks** - Multiple declarations for browser compatibility:

      ```elixir
      css_class :sticky,
        position: first_that_works(["sticky", "fixed"])
      # Generates: .class{position:fixed;position:sticky}
      ```

  2. **CSS variable fallbacks** - Nested var() with fallback values:

      ```elixir
      css_class :themed,
        background_color: first_that_works(["var(--bg-color)", "#808080"])
      # Generates: .class{background-color:var(--bg-color, #808080)}
      ```

  Values are tried in order - first value has highest priority.
  For CSS variables, they are nested: `var(--a, var(--b, fallback))`.

  ## Examples

      # Browser fallbacks (position: sticky not supported everywhere)
      css_class :sticky,
        position: first_that_works(["sticky", "fixed"])

      # CSS variable with fallback
      css_class :themed,
        color: first_that_works(["var(--theme-color)", "blue"])

      # Multiple CSS variables with final fallback
      css_class :multi_theme,
        color: first_that_works(["var(--primary)", "var(--fallback)", "black"])
  """
  @spec first_that_works(list()) :: map()
  def first_that_works(values) when is_list(values) do
    %{__fallback__: true, values: values}
  end

  # Delegate to Runtime module
  @doc false
  defdelegate resolve_class_string(module, refs, class_strings), to: LiveStyle.Runtime

  @doc false
  defdelegate resolve_attrs(module, refs, class_strings), to: LiveStyle.Runtime

  @doc false
  defdelegate process_dynamic_rule(all_props, param_names, values, module, name, has_computed),
    to: LiveStyle.Runtime

  @doc false
  defdelegate normalize_to_map(value), to: LiveStyle.Utils

  @doc """
  Returns the default marker class name for use with `LiveStyle.When` selectors.

  ## Example

      ~H\"\"\"
      <div class={LiveStyle.default_marker()}>
        <div class={style(:card)}>Hover parent to move me</div>
      </div>
      \"\"\"
  """
  defdelegate default_marker(), to: LiveStyle.Marker, as: :default

  @doc """
  Generates a unique marker class name for use with `LiveStyle.When` selectors.

  Custom markers allow you to have multiple independent sets of contextual selectors
  in the same component tree.

  ## Parameters

    * `name` - An atom identifying this marker

  ## Example

      @card_marker LiveStyle.define_marker(:card)
      @row_marker LiveStyle.define_marker(:row)
  """
  defdelegate define_marker(name), to: LiveStyle.Marker, as: :define

  @doc false
  defdelegate to_css_property(key), to: LiveStyle.Value

  @doc """
  Gets CSS attrs from a module that uses LiveStyle.

  This is the public API for accessing a module's styles from outside
  the module, primarily useful for testing.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        css_class :button, display: "flex"
      end

      # In tests:
      %LiveStyle.Attrs{class: class} = LiveStyle.get_css(MyComponent, [:button])
  """
  def get_css(module, refs) when is_atom(module) and is_list(refs) do
    class_strings = module.__live_style__(:class_strings)
    resolve_attrs(module, refs, class_strings)
  end

  def get_css(module, ref) when is_atom(module) and is_atom(ref) do
    class_strings = module.__live_style__(:class_strings)
    %LiveStyle.Attrs{class: Map.get(class_strings, ref, ""), style: nil}
  end

  @doc """
  Generates CSS from all registered styles.

  This reads the manifest and generates the complete CSS output.
  Primarily useful for testing and build tooling.

  ## Example

      css = LiveStyle.generate_css()
      # => "@layer live_style { .x1234{display:flex} ... }"
  """
  def generate_css do
    manifest = LiveStyle.Storage.read()
    LiveStyle.CSS.generate(manifest)
  end

  @doc """
  Gets the class string from a module that uses LiveStyle.

  This is the public API for accessing a module's styles from outside
  the module, primarily useful for testing.

  ## Example

      defmodule MyComponent do
        use LiveStyle
        css_class :button, display: "flex"
      end

      # In tests:
      class = LiveStyle.get_css_class(MyComponent, [:button])
  """
  def get_css_class(module, refs) when is_atom(module) and is_list(refs) do
    class_strings = module.__live_style__(:class_strings)
    resolve_class_string(module, refs, class_strings)
  end

  def get_css_class(module, ref) when is_atom(module) and is_atom(ref) do
    class_strings = module.__live_style__(:class_strings)
    Map.get(class_strings, ref, "")
  end

  @doc """
  Gets metadata for a LiveStyle artifact from the manifest.

  This is primarily useful for testing and introspection. It provides access
  to internal metadata like class names, CSS output, and priority levels.

  ## Examples

      # Get metadata for a style rule
      LiveStyle.get_metadata(MyComponent, :button)
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}

      # Get metadata for a style class
      LiveStyle.get_metadata(MyComponent, {:class, :button})
      # => %{class_string: "x1234 x5678", atomic_classes: %{...}, ...}

      # Get metadata for keyframes
      LiveStyle.get_metadata(MyComponent, {:keyframes, :spin})
      # => %{css_name: "x1abc", frames: %{...}}

      # Get metadata for a CSS variable
      LiveStyle.get_metadata(MyTokens, {:var, :colors, :primary})
      # => %{css_name: "--x1234", value: "blue", ...}

      # Get metadata for a theme
      LiveStyle.get_metadata(MyTokens, {:theme, :dark})
      # => %{css_name: "x1234", overrides: %{...}}
  """
  def get_metadata(module, {:class, name}) when is_atom(module) and is_atom(name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_class(manifest, key)
  end

  def get_metadata(module, {:keyframes, name}) when is_atom(module) and is_atom(name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_keyframes(manifest, key)
  end

  def get_metadata(module, {:var, namespace, name})
      when is_atom(module) and is_atom(namespace) and is_atom(name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_var(manifest, key)
  end

  def get_metadata(module, {:const, namespace, name})
      when is_atom(module) and is_atom(namespace) and is_atom(name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_const(manifest, key)
  end

  def get_metadata(module, {:theme, name}) when is_atom(module) and is_atom(name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_theme(manifest, key)
  end

  def get_metadata(module, {:theme, namespace, name})
      when is_atom(module) and is_atom(namespace) and is_atom(name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_theme(manifest, key)
  end

  def get_metadata(module, {:position_try, name}) when is_atom(module) and is_atom(name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_position_try(manifest, key)
  end

  def get_metadata(module, {:view_transition, name}) when is_atom(module) and is_atom(name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()
    Manifest.get_view_transition(manifest, key)
  end

  # Helper functions for __before_compile__

  @doc false
  def build_static_class_maps(static_classes, module) do
    Enum.reduce(static_classes, {%{}, %{}}, fn {name, _decl}, {cs_acc, pc_acc} ->
      build_static_class_map(name, module, cs_acc, pc_acc)
    end)
  end

  defp build_static_class_map(name, module, cs_acc, pc_acc) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_class(manifest, key) do
      %{class_string: cs, atomic_classes: atomic_classes} ->
        prop_classes = build_prop_classes(atomic_classes)
        {Map.put(cs_acc, name, cs), Map.put(pc_acc, name, prop_classes)}

      nil ->
        {Map.put(cs_acc, name, ""), Map.put(pc_acc, name, %{})}
    end
  end

  defp build_prop_classes(atomic_classes) do
    atomic_classes
    |> Enum.flat_map(&build_prop_class_entry/1)
    |> Map.new()
  end

  defp build_prop_class_entry({prop, %{class: nil, null: true}}) do
    [{prop, :__null__}]
  end

  defp build_prop_class_entry({prop, %{class: class}}) when class != nil do
    [{prop, class}]
  end

  defp build_prop_class_entry({prop, %{classes: classes}}) do
    Enum.flat_map(classes, fn entry -> build_conditional_entry(prop, entry) end)
  end

  defp build_prop_class_entry(_), do: []

  defp build_conditional_entry(prop, {condition, %{class: nil}}) do
    [{"#{prop}::#{condition}", :__null__}]
  end

  defp build_conditional_entry(prop, {condition, %{class: class}}) when class != nil do
    [{"#{prop}::#{condition}", class}]
  end

  defp build_conditional_entry(_prop, _), do: []

  @doc false
  def build_dynamic_fns(dynamic_rules, module) do
    Enum.map(dynamic_rules, fn {name, {:__dynamic__, all_props, param_names, has_computed}} ->
      fn_name = :"__dynamic_#{name}__"

      quote do
        @doc false
        def unquote(fn_name)(values) do
          LiveStyle.process_dynamic_rule(
            unquote(Macro.escape(all_props)),
            unquote(param_names),
            values,
            unquote(module),
            unquote(name),
            unquote(has_computed)
          )
        end
      end
    end)
  end
end
