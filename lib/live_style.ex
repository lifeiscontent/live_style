defmodule LiveStyle do
  @moduledoc """
  LiveStyle - Compile-time CSS-in-Elixir for Phoenix LiveView.

  All style definitions compile away to string constants. At runtime,
  only class name strings exist - no function calls or manifest lookups.

  ## Basic Usage

      defmodule MyApp.Button do
        use Phoenix.Component
        use LiveStyle

        # Define CSS variables
        vars primary: "#3b82f6",
             white: "#ffffff"

        # Define a theme that overrides variables
        theme :dark,
          primary: "#60a5fa",
          white: "#1f2937"

        # Define keyframes
        keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]

        # Define classes
        class :base,
          display: "inline-flex",
          padding: "0.5rem 1rem"

        class :styled,
          background_color: var(:primary),
          color: var(:white)

        def render(assigns) do
          ~H\"\"\"
          <button {css([:base, :styled])}>
            <%= render_slot(@inner_block) %>
          </button>
          \"\"\"
        end
      end

  ## Reference Syntax

  Cross-module references:
  - `var({Module, :name})` - Reference a CSS variable
  - `const({Module, :name})` - Reference a compile-time constant
  - `keyframes({Module, :name})` - Reference a keyframes animation
  - `theme({Module, :name})` - Reference a theme class
  - `position_try({Module, :name})` - Reference a position-try rule
  - `view_transition_class({Module, :name})` - Reference a view transition

  Local references (within the same module):
  - `var(:name)`
  - `keyframes(:name)`
  - `theme(:name)`

  ## Public API Functions

  - `LiveStyle.default_marker/0` - Get the default marker class for contextual selectors
  - `LiveStyle.marker/1` - Get a custom marker class

  For testing (see `LiveStyle.Compiler`):
  - `LiveStyle.Compiler.get_css/2` - Get `%LiveStyle.Attrs{}` from a module's classes
  - `LiveStyle.Compiler.get_css_class/2` - Get class string from a module's classes
  - `LiveStyle.Compiler.generate_css/0` - Generate all CSS output

  See the README for comprehensive documentation and examples.
  """

  defmacro __using__(_opts \\ []) do
    quote do
      import LiveStyle,
        only: [
          # Definition macros
          vars: 1,
          consts: 1,
          keyframes: 2,
          position_try: 2,
          view_transition_class: 2,
          class: 2,
          theme: 2,
          # Reference macros
          var: 1,
          const: 1,
          keyframes: 1,
          position_try: 1,
          view_transition_class: 1,
          theme: 1,
          # Runtime resolution macros (validates at compile time, resolves at runtime)
          css: 1,
          css: 2,
          # Composition
          include: 1,
          # Utilities
          fallback: 1
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
    alias LiveStyle.Compiler.BeforeCompile

    manifest = LiveStyle.Storage.read()

    {class_strings, property_classes} =
      BeforeCompile.build_static_class_maps(static_classes, env.module, manifest)

    # Generate dynamic class functions
    # Dynamic classes: {name, {:__dynamic__, all_props, param_names, has_computed}}
    dynamic_fns = BeforeCompile.build_dynamic_fns(dynamic_classes, env.module)

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
    end
  end

  @doc """
  Defines CSS custom properties (variables).

  ## Examples

      vars white: "#ffffff",
           primary: "#3b82f6",
           spacing_sm: "0.5rem",
           spacing_lg: "2rem"

  For typed variables that can be animated, use `LiveStyle.PropertyType`:

      import LiveStyle.PropertyType

      vars angle: angle("0deg"),
           hue: percentage("0%")
  """
  defmacro vars(vars_list) do
    # Evaluate vars at compile time so they're available for var references
    {evaluated_vars, _} = Code.eval_quoted(vars_list, [], __CALLER__)
    module = __CALLER__.module

    # Store immediately during macro expansion
    # so that var/1 references in the same module can find them
    LiveStyle.Vars.define(module, evaluated_vars)

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

      var(:white)

  ## Cross-module reference

      var({MyApp.Tokens, :white})

  ## Using in keyframes (animating typed variables)

      keyframes :rotate,
        from: [{var({Tokens, :angle}), "0deg"}],
        to: [{var({Tokens, :angle}), "360deg"}]
  """
  defmacro var(ref) when is_atom(ref) do
    # Local reference: :name
    module = __CALLER__.module
    LiveStyle.Vars.var({module, ref})
  end

  defmacro var({module_ast, name}) when is_atom(name) do
    # Cross-module: {Module, :name}
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.Vars.var({module, name})
  end

  @doc """
  Defines compile-time constants (no CSS output).

  ## Examples

      consts breakpoint_sm: "@media (max-width: 640px)",
             breakpoint_lg: "@media (min-width: 1025px)",
             z_modal: "50",
             z_tooltip: "100"
  """
  defmacro consts(consts_list) do
    # Evaluate consts at compile time so they're available for const references
    {evaluated_consts, _} = Code.eval_quoted(consts_list, [], __CALLER__)
    module = __CALLER__.module

    # Store immediately during macro expansion
    # so that const/1 references in the same module can find them
    LiveStyle.Consts.define(module, evaluated_consts)

    quote do
      :ok
    end
  end

  @doc """
  References a constant, returning its raw value.

  ## Local reference

      const(:breakpoint_lg)

  ## Cross-module reference

      const({MyApp.Tokens, :breakpoint_lg})

  Note: Requires the defining module to be compiled first.
  """
  defmacro const(ref) when is_atom(ref) do
    # Local reference: :name
    module = __CALLER__.module
    LiveStyle.Consts.ref({module, ref})
  end

  defmacro const({module_ast, name}) when is_atom(name) do
    # Cross-module: {Module, :name}
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.Consts.ref({module, name})
  end

  @doc """
  Defines a keyframes animation (2-arg form) or references one (1-arg form).

  ## Definition (2 args)

      keyframes :spin,
        from: [transform: "rotate(0deg)"],
        to: [transform: "rotate(360deg)"]

      keyframes :fade_in,
        "0%": [opacity: "0"],
        "100%": [opacity: "1"]

  ## Local reference (1 arg)

      keyframes(:spin)

  ## Cross-module reference

      keyframes({MyApp.Tokens, :spin})
  """
  defmacro keyframes(name, frames) when is_atom(name) do
    {evaluated_frames, _} = Code.eval_quoted(frames, [], __CALLER__)
    module = __CALLER__.module

    # Define keyframes and store in manifest
    LiveStyle.Keyframes.define(module, name, evaluated_frames)

    quote do
      :ok
    end
  end

  defmacro keyframes(ref) when is_atom(ref) do
    module = __CALLER__.module
    LiveStyle.Keyframes.ref({module, ref})
  end

  defmacro keyframes({module_ast, name}) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.Keyframes.ref({module, name})
  end

  @doc """
  Defines or references a @position-try rule for anchor positioning.

  ## Definition (2 args)

      position_try :bottom_fallback,
        top: "anchor(bottom)",
        left: "anchor(left)"

  ## Local reference (1 arg atom)

      position_try(:bottom_fallback)

  ## Cross-module reference (1 arg tuple)

      position_try({MyApp.Tokens, :bottom_fallback})
  """
  defmacro position_try(name, declarations) when is_atom(name) do
    # Evaluate declarations at compile time for content-based hashing (StyleX behavior)
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = LiveStyle.Utils.validate_keyword_list!(evaluated)

    # Normalize values (add px to numbers, etc.)
    normalized_values =
      Enum.map(normalized, fn {k, v} -> {k, LiveStyle.PositionTry.normalize_value(v)} end)

    # Generate CSS string for hashing (StyleX format: sorted keys, "key:value;" no spaces)
    ident = LiveStyle.PositionTry.generate_ident(normalized_values)

    quote do
      LiveStyle.PositionTry.define(
        __MODULE__,
        unquote(name),
        unquote(Macro.escape(normalized_values)),
        unquote(ident)
      )
    end
  end

  defmacro position_try(ref) when is_atom(ref) do
    module = __CALLER__.module
    LiveStyle.PositionTry.ref({module, ref})
  end

  defmacro position_try({module_ast, name}) when is_atom(name) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.PositionTry.ref({module, name})
  end

  # Inline anonymous position-try: position_try(top: "0", left: "0")
  # Returns a content-hashed dashed-ident name (like StyleX positionTry)
  defmacro position_try(declarations) when is_list(declarations) do
    module = __CALLER__.module
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = LiveStyle.Utils.validate_keyword_list!(evaluated)

    # Validate and normalize declarations
    case LiveStyle.PositionTry.validate_declarations(normalized) do
      {:ok, normalized_values} ->
        ident = LiveStyle.PositionTry.generate_ident(normalized_values)
        LiveStyle.PositionTry.define_anonymous(module, normalized_values, ident)
        ident

      {:error, invalid_props} ->
        allowed = LiveStyle.PositionTry.allowed_properties()

        raise ArgumentError, """
        Invalid properties in position_try: #{inspect(invalid_props)}

        Only these properties are allowed in @position-try rules:
        #{Enum.join(allowed, ", ")}
        """
    end
  end

  @doc """
  Defines a view transition class.

  ## Examples

      view_transition_class :card_transition,
        old: [animation_name: keyframes(:fade_out), animation_duration: "250ms"],
        new: [animation_name: keyframes(:fade_in), animation_duration: "250ms"]
  """
  defmacro view_transition_class(name, styles) when is_atom(name) do
    # Evaluate styles at compile time to resolve keyframes references
    {evaluated_styles, _} = Code.eval_quoted(styles, [], __CALLER__)

    # Validate keys at compile time
    style_map = LiveStyle.Utils.validate_keyword_list!(evaluated_styles)

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
    ident = LiveStyle.ViewTransition.generate_ident(evaluated_styles)

    quote do
      LiveStyle.ViewTransition.define(
        __MODULE__,
        unquote(name),
        unquote(Macro.escape(evaluated_styles)),
        unquote(ident)
      )
    end
  end

  @doc """
  References a view transition, returning the `view-transition-class` value.

  Returns the hashed class name that should be used with the CSS `view-transition-class`
  property. You control when and where to apply `view-transition-name` via inline styles.

  ## Local reference

      view_transition_class(:card)
      # => "x9fx6z8"

  ## Cross-module reference

      view_transition_class({Tokens, :card})
      # => "x9fx6z8"

  ## Usage in templates

  Use with inline styles to control view transitions:

      <div style={"view-transition-class: \#{view_transition_class(:card)}; view-transition-name: card-\#{@id}"}>

  Or use `css/2` with the `style` option for merging with other styles:

      <div {css([:card_styles], style: [view_transition_class: view_transition_class(:card), view_transition_name: "card-\#{@id}"])}>
  """
  # Local reference: view_transition_class(:name)
  defmacro view_transition_class(ref) when is_atom(ref) do
    module = __CALLER__.module
    LiveStyle.ViewTransition.ref({module, ref})
  end

  # Cross-module reference: view_transition_class({Module, :name})
  defmacro view_transition_class({module_ast, name}) when is_atom(name) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.ViewTransition.ref({module, name})
  end

  @doc """
  Defines a style class with CSS declarations.

  ## Static classes

      class :button,
        display: "flex",
        padding: "8px 16px"

  ## With variable references

      class :themed,
        color: var({MyApp.Tokens, :white})

  ## Conditional styles (pseudo-classes, media queries)

      class :interactive,
        color: [
          default: "blue",
          ":hover": "darkblue",
          "@media (prefers-color-scheme: dark)": "lightblue"
        ]

  ## Conditional syntax (StyleX-style)

  LiveStyle follows modern StyleX conditional syntax: conditions live inside each
  property's value (keyword list), rather than using top-level at-rule keys.

      class :responsive_card,
        padding: [
          default: "1rem",
          "@container (min-width: 400px)": "2rem",
          "@media (min-width: 768px)": "3rem"
        ]

  ## Dynamic classes (StyleX-style with CSS variables)

  Dynamic classes use a function that declares which properties can be set at runtime.
  The CSS is generated with `var(--x-property)` references, and at runtime only
  the CSS variable values are set via inline style.

      # Single parameter
      class :dynamic_opacity, fn opacity -> [opacity: opacity] end

      # Multiple parameters
      class :dynamic_size, fn width, height -> [width: width, height: height] end

  Usage:
      <div {css([:base, {:dynamic_opacity, "0.5"}])}>
      <div {css([:base, {:dynamic_size, ["100px", "200px"]}])}>
  """
  defmacro class(name, declarations) when is_atom(name) and is_list(declarations) do
    # Static class - keyword list of declarations
    # Defer evaluation to runtime within the module to access module attributes
    module = __CALLER__.module
    file = __CALLER__.file
    line = __CALLER__.line
    class_module = LiveStyle.Compiler.Class

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.Utils.validate_keyword_list!(declarations_evaluated)

      unquote(class_module).define(
        unquote(module),
        unquote(name),
        normalized,
        file: unquote(file),
        line: unquote(line)
      )

      @__live_style_classes__ {unquote(name), normalized}
    end
  end

  # Static class with map syntax - class(:name, %{...})
  # This will fail with validate_keyword_list! - maps are not supported
  defmacro class(name, {:%{}, _, _} = declarations) when is_atom(name) do
    module = __CALLER__.module
    file = __CALLER__.file
    line = __CALLER__.line
    class_module = LiveStyle.Compiler.Class

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.Utils.validate_keyword_list!(declarations_evaluated)

      unquote(class_module).define(
        unquote(module),
        unquote(name),
        normalized,
        file: unquote(file),
        line: unquote(line)
      )

      @__live_style_classes__ {unquote(name), normalized}
    end
  end

  # Dynamic class - function that returns declarations
  # class :dynamic_opacity, fn opacity -> [opacity: opacity] end
  defmacro class(name, {:fn, _, [{:->, _, [params, body]}]} = func) when is_atom(name) do
    module = __CALLER__.module
    class_module = LiveStyle.Compiler.Class

    # Extract parameter names from the function
    param_names = extract_param_names(params)

    # Expand macros in the function body to get the declarations.
    # We do a deep expansion so css_var/2 can be used
    # in dynamic class keys.
    expanded_body = Macro.prewalk(body, fn ast -> Macro.expand(ast, __CALLER__) end)

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
      unquote(class_module).define_dynamic(
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
  Returns CSS attributes for spreading in HEEx templates.

  Returns `%LiveStyle.Attrs{}` for use with the spread syntax `{css(...)}`
  in templates. This handles both static and dynamic styles that set CSS
  variables via inline style.

  ## Examples

      # Single ref
      <div {css(:button)}>

      # List of refs with conditionals
      <div {css([:base, @active && :active])}>

      # Dynamic styles
      <div {css([{:dynamic_color, @color}])}>

      # With additional inline styles
      <div {css([:card], style: [view_transition_name: "card-1"])}>

      # With view transitions
      <div {css([:card], style: [
        view_transition_class: view_transition_class(:card),
        view_transition_name: "card-\#{@id}"
      ])}>
  """
  # Single atom reference: css(:button)
  # Returns Attrs struct for spreading in templates
  defmacro css(name) when is_atom(name) do
    quote do
      %LiveStyle.Attrs{
        class: Keyword.get(__MODULE__.__live_style__(:class_strings), unquote(name), ""),
        style: nil
      }
    end
  end

  # List of refs: css([:base, :primary, @active && :active])
  # Resolves and merges multiple refs at runtime, returns Attrs struct
  defmacro css(refs) when is_list(refs) do
    quote do
      LiveStyle.resolve_attrs(__MODULE__, unquote(refs), nil)
    end
  end

  @doc """
  Returns CSS attributes with additional inline styles merged in.

  The second argument is a keyword list with a `:style` key containing
  additional CSS properties to merge into the inline style.

  ## Options

    * `:style` - A keyword list of CSS properties to merge.
      Property names should be atoms (snake_case).

  ## Examples

      # With view transition styles
      <div {css([:card], style: [
        view_transition_class: view_transition_class(:card),
        view_transition_name: "card-\#{@id}"
      ])}>

      # With arbitrary inline styles
      <div {css([:base], style: [opacity: "0.5", transform: "scale(1.1)"])}>
  """
  defmacro css(refs, opts) when is_list(opts) do
    quote do
      LiveStyle.resolve_attrs(__MODULE__, unquote(refs), unquote(opts))
    end
  end

  @doc """
  Defines a theme (variable overrides).

  Similar to StyleX's `createTheme`, this creates a class that overrides
  CSS variables defined with `vars`.

  ## Examples

      # First define your variables
      vars white: "#ffffff",
           primary: "#3b82f6"

      # Then create a theme that overrides those variables
      theme :dark,
        white: "#000000",
        primary: "#8ab4f8"
  """
  defmacro theme(name, overrides) when is_atom(name) do
    module = __CALLER__.module
    ident = LiveStyle.Theme.generate_ident(module, name)

    quote do
      LiveStyle.Theme.define(
        unquote(module),
        unquote(name),
        unquote(overrides),
        unquote(ident)
      )
    end
  end

  @doc """
  References a theme, returning the class name.

  ## Local reference

      theme(:dark)

  ## Cross-module reference

      theme({MyApp.Tokens, :dark})
  """
  defmacro theme(ref) when is_atom(ref) do
    # Local reference: :name
    module = __CALLER__.module
    LiveStyle.Theme.ref({module, ref})
  end

  defmacro theme({module_ast, name}) when is_atom(name) do
    # Cross-module: {Module, :name}
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)
    LiveStyle.Theme.ref({module, name})
  end

  @doc """
  Creates fallback values for CSS properties (StyleX `firstThatWorks` equivalent).

  This function handles two cases:

  1. **Regular fallbacks** - Multiple declarations for browser compatibility:

      ```elixir
      class :sticky,
        position: fallback(["sticky", "fixed"])
      # Generates: .class{position:fixed;position:sticky}
      ```

  2. **CSS variable fallbacks** - Nested var() with fallback values:

      ```elixir
      class :themed,
        background_color: fallback(["var(--bg-color)", "#808080"])
      # Generates: .class{background-color:var(--bg-color, #808080)}
      ```

  Values are tried in order - first value has highest priority.
  For CSS variables, they are nested: `var(--a, var(--b, fallback))`.

  ## Examples

      # Browser fallbacks (position: sticky not supported everywhere)
      class :sticky,
        position: fallback(["sticky", "fixed"])

      # CSS variable with fallback
      class :themed,
        color: fallback(["var(--theme-color)", "blue"])

      # Multiple CSS variables with final fallback
      class :multi_theme,
        color: fallback(["var(--primary)", "var(--fallback)", "black"])
  """
  @spec fallback(list()) :: {:__fallback__, list()}
  def fallback(values) when is_list(values) do
    {:__fallback__, values}
  end

  @doc """
  Includes styles from another class.

  Used inside `class/2` definitions for style composition. Included styles
  are merged with the current class using last-wins semantics - properties
  defined after `include()` override properties from included classes.

  ## Examples

      # Include a local class
      class :primary, [
        include(:base),
        background_color: "blue"
      ]

      # Include from another module
      class :themed, [
        include({OtherModule, :base}),
        color: "white"
      ]

      # Multiple includes
      class :fancy, [
        include(:base),
        include(:rounded),
        include({SharedStyles, :animated}),
        border_radius: "12px"
      ]
  """
  @spec include(atom() | {module(), atom()}) :: {:__include__, atom() | {module(), atom()}}
  def include(ref) when is_atom(ref), do: {:__include__, ref}

  def include({module, name}) when is_atom(module) and is_atom(name),
    do: {:__include__, {module, name}}

  # Delegate to Runtime module
  @doc false
  defdelegate resolve_class_string(module, refs),
    to: LiveStyle.Runtime

  @doc false
  defdelegate resolve_attrs(module, refs, opts),
    to: LiveStyle.Runtime

  @doc false
  defdelegate process_dynamic_rule(all_props, param_names, values, module, name, has_computed),
    to: LiveStyle.Runtime

  @doc """
  Returns the default marker class name for use with `LiveStyle.When` selectors.

  ## Example

      <div class={default_marker()}>
        <div {css(:card)}>Hover parent to move me</div>
      </div>
  """
  defdelegate default_marker(), to: LiveStyle.Marker, as: :default

  @doc """
  Returns a marker class name for use with `LiveStyle.When` selectors.

  Custom markers allow you to have multiple independent sets of contextual selectors
  in the same component tree.

  ## Examples

      # Local marker
      marker(:row)

      # Cross-module marker
      marker({OtherModule, :row})

  ## Usage

      <tr class={marker(:row)}>
        <td {css(:cell)}>...</td>
      </tr>
  """
  @spec marker(atom() | {module(), atom()}) :: LiveStyle.Marker.t()
  def marker(name) when is_atom(name) do
    LiveStyle.Marker.ref(name)
  end

  def marker({_module, name}) when is_atom(name) do
    # Module is ignored since markers are content-hashed by name only
    LiveStyle.Marker.ref(name)
  end
end
