defmodule LiveStyle do
  @moduledoc """
  LiveStyle - Compile-time CSS-in-Elixir for Phoenix LiveView.

  All style definitions compile away to string constants. At runtime,
  only class name strings exist - no function calls or manifest lookups.

  ## Basic Usage

      defmodule MyAppWeb.Button do
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
  - `theme_class({Module, :name})` - Reference a theme class
  - `position_try({Module, :name})` - Reference a position-try rule
  - `view_transition({Module, :name})` - Reference a view transition

  Local references (within the same module):
  - `var(:name)`
  - `keyframes(:name)`
  - `theme_class(:name)`

  ## Public API Functions

  - `LiveStyle.default_marker/0` - Get the default marker class for contextual selectors
  - `LiveStyle.marker/1` - Get a custom marker class

  See the README for comprehensive documentation and examples.
  """

  defmacro __using__(_opts \\ []) do
    # Register attributes IMMEDIATELY during macro expansion (not in quote)
    # This ensures accumulate: true is set before any vars/class calls
    module = __CALLER__.module
    Module.register_attribute(module, :__live_style_classes__, accumulate: true)
    Module.register_attribute(module, :__live_style_vars__, accumulate: true)
    Module.register_attribute(module, :__live_style_consts__, accumulate: true)
    Module.register_attribute(module, :__live_style_keyframes__, accumulate: true)
    Module.register_attribute(module, :__live_style_theme_classes__, accumulate: true)
    Module.register_attribute(module, :__live_style_view_transition_classes__, accumulate: true)
    Module.register_attribute(module, :__live_style_position_try__, accumulate: true)

    quote do
      import LiveStyle,
        only: [
          # Definition macros
          vars: 1,
          consts: 1,
          keyframes: 2,
          position_try: 2,
          view_transition: 2,
          class: 2,
          theme: 2,
          # Reference macros
          var: 1,
          const: 1,
          keyframes: 1,
          position_try: 1,
          view_transition_class: 1,
          theme_class: 1,
          # Runtime resolution macros (validates at compile time, resolves at runtime)
          css: 1,
          css: 2,
          # Composition
          include: 1,
          # Utilities
          fallback: 1
        ]

      @before_compile LiveStyle
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(env) do
    classes = Module.get_attribute(env.module, :__live_style_classes__) |> Enum.reverse()
    module = env.module

    # Separate static from dynamic classes
    # Static classes have format: {name, declarations, opts}
    # Dynamic classes have format: {name, {:__dynamic__, all_props, has_computed}}
    {static_classes, dynamic_classes} =
      Enum.split_with(classes, fn
        {_name, {:__dynamic__, _, _}} -> false
        {_name, _declarations, _opts} -> true
        # Legacy format without opts (shouldn't happen, but be safe)
        {_name, decl} -> not match?({:__dynamic__, _, _}, decl)
      end)

    alias LiveStyle.Class
    alias LiveStyle.Compiler.BeforeCompile

    # BATCH WRITE: Define all classes in a single manifest update
    # This dramatically reduces lock contention during compilation
    LiveStyle.Storage.update(fn manifest ->
      # Define all static classes
      manifest =
        Enum.reduce(static_classes, manifest, fn class_entry, acc ->
          {name, declarations, opts} = BeforeCompile.normalize_class_entry(class_entry)
          Class.batch_define(acc, module, name, declarations, opts)
        end)

      # Define all dynamic classes
      Enum.reduce(dynamic_classes, manifest, fn {name, {:__dynamic__, all_props, _has_computed}},
                                                acc ->
        Class.batch_define_dynamic(acc, module, name, all_props)
      end)
    end)

    # Now read the updated manifest to build class maps
    manifest = LiveStyle.Storage.read()

    # Build class_strings and property_classes for ALL classes (static + dynamic)
    # This matches StyleX behavior where dynamic classes also have property-based merging
    all_classes = static_classes ++ dynamic_classes

    {class_strings, property_classes} =
      BeforeCompile.build_class_maps(all_classes, module, manifest)

    # Generate dynamic class functions (only compute var_list at runtime)
    dynamic_fns = BeforeCompile.build_dynamic_fns(dynamic_classes, module)

    dynamic_names = Enum.map(dynamic_classes, fn {name, _} -> name end)

    # Get accumulated var entries
    vars = Module.get_attribute(env.module, :__live_style_vars__) || []
    vars_map = Map.new(vars)

    # Get accumulated const entries
    consts = Module.get_attribute(env.module, :__live_style_consts__) || []
    consts_map = Map.new(consts)

    # Get accumulated keyframes entries
    keyframes = Module.get_attribute(env.module, :__live_style_keyframes__) || []
    keyframes_map = Map.new(keyframes)

    # Get accumulated theme_class entries
    theme_classes = Module.get_attribute(env.module, :__live_style_theme_classes__) || []
    theme_classes_map = Map.new(theme_classes)

    # Get accumulated view_transition_class entries
    view_transition_classes =
      Module.get_attribute(env.module, :__live_style_view_transition_classes__) || []

    view_transition_classes_map = Map.new(view_transition_classes)

    # Get accumulated position_try entries
    position_try = Module.get_attribute(env.module, :__live_style_position_try__) || []
    position_try_map = Map.new(position_try)

    # Generate var lookup function clauses
    var_clauses =
      for {name, entry} <- vars do
        quote do
          def __live_style__(:var, unquote(name)), do: unquote(Macro.escape(entry))
        end
      end

    # Generate const lookup function clauses
    const_clauses =
      for {name, value} <- consts do
        quote do
          def __live_style__(:const, unquote(name)), do: unquote(value)
        end
      end

    # Generate keyframes lookup function clauses
    keyframes_clauses =
      for {name, entry} <- keyframes do
        quote do
          def __live_style__(:keyframes, unquote(name)), do: unquote(Macro.escape(entry))
        end
      end

    # Generate theme_class lookup function clauses
    theme_class_clauses =
      for {name, entry} <- theme_classes do
        quote do
          def __live_style__(:theme_class, unquote(name)), do: unquote(Macro.escape(entry))
        end
      end

    # Generate view_transition_class lookup function clauses
    view_transition_class_clauses =
      for {name, entry} <- view_transition_classes do
        quote do
          def __live_style__(:view_transition_class, unquote(name)),
            do: unquote(Macro.escape(entry))
        end
      end

    # Generate position_try lookup function clauses
    position_try_clauses =
      for {name, entry} <- position_try do
        quote do
          def __live_style__(:position_try, unquote(name)), do: unquote(Macro.escape(entry))
        end
      end

    # Generate class lookup function clauses (for cross-module includes)
    # We need to look up class entries from the manifest for each class
    class_clauses =
      for class_entry <- all_classes do
        name = elem(class_entry, 0)
        key = LiveStyle.Manifest.key(module, name)

        case LiveStyle.Manifest.get_class(manifest, key) do
          entry when is_list(entry) ->
            quote do
              def __live_style__(:class, unquote(name)), do: unquote(Macro.escape(entry))
            end

          nil ->
            quote do
              def __live_style__(:class, unquote(name)), do: nil
            end
        end
      end

    quote do
      @__class_strings__ unquote(Macro.escape(class_strings))
      @__property_classes__ unquote(Macro.escape(property_classes))
      @__dynamic_names__ unquote(dynamic_names)
      @__vars__ unquote(Macro.escape(vars_map))
      @__consts__ unquote(Macro.escape(consts_map))
      @__keyframes__ unquote(Macro.escape(keyframes_map))
      @__theme_classes__ unquote(Macro.escape(theme_classes_map))
      @__view_transition_classes__ unquote(Macro.escape(view_transition_classes_map))
      @__position_try__ unquote(Macro.escape(position_try_map))

      unquote_splicing(dynamic_fns)
      unquote_splicing(var_clauses)
      unquote_splicing(const_clauses)
      unquote_splicing(keyframes_clauses)
      unquote_splicing(theme_class_clauses)
      unquote_splicing(view_transition_class_clauses)
      unquote_splicing(position_try_clauses)
      unquote_splicing(class_clauses)

      @doc false
      def __live_style__(:class_strings), do: @__class_strings__
      def __live_style__(:property_classes), do: @__property_classes__
      def __live_style__(:dynamic_names), do: @__dynamic_names__
      def __live_style__(:vars), do: @__vars__
      def __live_style__(:consts), do: @__consts__
      def __live_style__(:keyframes), do: @__keyframes__
      def __live_style__(:theme_classes), do: @__theme_classes__
      def __live_style__(:view_transition_classes), do: @__view_transition_classes__
      def __live_style__(:position_try), do: @__position_try__

      # Fallback for lookups - returns nil if not found
      def __live_style__(:var, _name), do: nil
      def __live_style__(:const, _name), do: nil
      def __live_style__(:keyframes, _name), do: nil
      def __live_style__(:theme_class, _name), do: nil
      def __live_style__(:view_transition_class, _name), do: nil
      def __live_style__(:position_try, _name), do: nil
      def __live_style__(:class, _name), do: nil
    end
  end

  @doc """
  Defines CSS custom properties (variables).

  ## Examples

      vars white: "#ffffff",
           primary: "#3b82f6",
           spacing_sm: "0.5rem",
           spacing_lg: "2rem"

  For typed variables that can be animated, use `LiveStyle.Types`:

      import LiveStyle.Types

      vars angle: angle("0deg"),
           hue: percentage("0%")
  """
  defmacro vars(vars_list) do
    # Evaluate vars at compile time so they're available for var references
    {evaluated_vars, _} = Code.eval_quoted(vars_list, [], __CALLER__)
    module = __CALLER__.module

    # Store immediately during macro expansion and get entries back
    # This stores in manifest (for CSS generation) and returns entries
    entries = LiveStyle.Vars.define(module, evaluated_vars)

    # Store entries in module attribute IMMEDIATELY during macro expansion
    # so that subsequent var/1 calls in the same module can find them
    for {name, entry} <- entries do
      Module.put_attribute(module, :__live_style_vars__, {name, entry})
    end

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

      var({MyAppWeb.Tokens, :white})

  ## Using in keyframes (animating typed variables)

      keyframes :rotate,
        from: [{var({Tokens, :angle}), "0deg"}],
        to: [{var({Tokens, :angle}), "360deg"}]
  """
  defmacro var(ref) when is_atom(ref) do
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated vars (already a list due to accumulate: true)
    vars = Module.get_attribute(caller_module, :__live_style_vars__) || []

    case List.keyfind(vars, ref, 0) do
      {^ref, entry} ->
        ident = Keyword.fetch!(entry, :ident)
        "var(#{ident})"

      nil ->
        raise CompileError,
          description:
            "CSS variable :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `vars #{ref}: ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  defmacro var({module_ast, name}) when is_atom(name) do
    # Cross-module: call module.__live_style__(:var, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    # This call ensures `module` is compiled before the current module
    case module.__live_style__(:var, name) do
      nil ->
        raise CompileError,
          description:
            "CSS variable :#{name} not found in #{inspect(module)}. " <>
              "Make sure `vars #{name}: ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      entry ->
        ident = Keyword.fetch!(entry, :ident)
        "var(#{ident})"
    end
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

    # Store in manifest (for CSS generation) and get entries back
    entries = LiveStyle.Consts.define(module, evaluated_consts)

    # Store entries in module attribute IMMEDIATELY during macro expansion
    # so that subsequent const/1 calls in the same module can find them
    for {name, value} <- entries do
      Module.put_attribute(module, :__live_style_consts__, {name, value})
    end

    quote do
      :ok
    end
  end

  @doc """
  References a constant, returning its raw value.

  ## Local reference

      const(:breakpoint_lg)

  ## Cross-module reference

      const({MyAppWeb.Tokens, :breakpoint_lg})
  """
  defmacro const(ref) when is_atom(ref) do
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated consts (already a list due to accumulate: true)
    consts = Module.get_attribute(caller_module, :__live_style_consts__) || []

    case List.keyfind(consts, ref, 0) do
      {^ref, value} ->
        value

      nil ->
        raise CompileError,
          description:
            "Constant :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `consts #{ref}: ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  defmacro const({module_ast, name}) when is_atom(name) do
    # Cross-module: call module.__live_style__(:const, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    # This call ensures `module` is compiled before the current module
    case module.__live_style__(:const, name) do
      nil ->
        raise CompileError,
          description:
            "Constant :#{name} not found in #{inspect(module)}. " <>
              "Make sure `consts #{name}: ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      value ->
        value
    end
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

      keyframes({MyAppWeb.Tokens, :spin})
  """
  defmacro keyframes(name, frames) when is_atom(name) do
    {evaluated_frames, _} = Code.eval_quoted(frames, [], __CALLER__)
    module = __CALLER__.module

    # Define keyframes and store in manifest, get entry back
    {^name, entry} = LiveStyle.Keyframes.define(module, name, evaluated_frames)

    # Store in module attribute IMMEDIATELY during macro expansion
    Module.put_attribute(module, :__live_style_keyframes__, {name, entry})

    quote do
      :ok
    end
  end

  defmacro keyframes(ref) when is_atom(ref) do
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated keyframes (already a list due to accumulate: true)
    keyframes_list = Module.get_attribute(caller_module, :__live_style_keyframes__) || []

    case List.keyfind(keyframes_list, ref, 0) do
      {^ref, entry} ->
        Keyword.fetch!(entry, :ident)

      nil ->
        raise CompileError,
          description:
            "Keyframes :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `keyframes :#{ref}, ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  defmacro keyframes({module_ast, name}) do
    # Cross-module: call module.__live_style__(:keyframes, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    case module.__live_style__(:keyframes, name) do
      nil ->
        raise CompileError,
          description:
            "Keyframes :#{name} not found in #{inspect(module)}. " <>
              "Make sure `keyframes :#{name}, ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      entry ->
        Keyword.fetch!(entry, :ident)
    end
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

      position_try({MyAppWeb.Tokens, :bottom_fallback})
  """
  defmacro position_try(name, declarations) when is_atom(name) do
    # Evaluate declarations at compile time for content-based hashing (StyleX behavior)
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = LiveStyle.Utils.validate_keyword_list!(evaluated)
    module = __CALLER__.module

    # Normalize values (add px to numbers, etc.)
    normalized_values =
      Enum.map(normalized, fn {k, v} -> {k, LiveStyle.PositionTry.normalize_value(v)} end)

    # Define position_try and store in manifest, get entry back
    {^name, entry} = LiveStyle.PositionTry.define(module, name, normalized_values)

    # Store in module attribute IMMEDIATELY during macro expansion
    Module.put_attribute(module, :__live_style_position_try__, {name, entry})

    quote do
      :ok
    end
  end

  defmacro position_try(ref) when is_atom(ref) do
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated position_try (already a list due to accumulate: true)
    pt_list = Module.get_attribute(caller_module, :__live_style_position_try__) || []

    case List.keyfind(pt_list, ref, 0) do
      {^ref, entry} ->
        Keyword.fetch!(entry, :ident)

      nil ->
        raise CompileError,
          description:
            "Position-try :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `position_try :#{ref}, ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  defmacro position_try({module_ast, name}) when is_atom(name) do
    # Cross-module: call module.__live_style__(:position_try, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    case module.__live_style__(:position_try, name) do
      nil ->
        raise CompileError,
          description:
            "Position-try :#{name} not found in #{inspect(module)}. " <>
              "Make sure `position_try :#{name}, ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      entry ->
        Keyword.fetch!(entry, :ident)
    end
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
        LiveStyle.PositionTry.define_anonymous(module, normalized_values)

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
  Defines a view transition.

  ## Examples

      view_transition :card_transition,
        old: [animation_name: keyframes(:fade_out), animation_duration: "250ms"],
        new: [animation_name: keyframes(:fade_in), animation_duration: "250ms"]
  """
  defmacro view_transition(name, styles) when is_atom(name) do
    # Evaluate styles at compile time to resolve keyframes references
    {evaluated_styles, _} = Code.eval_quoted(styles, [], __CALLER__)
    module = __CALLER__.module

    # Validate keys at compile time
    style_map = LiveStyle.Utils.validate_keyword_list!(evaluated_styles)

    case LiveStyle.ViewTransitionClass.validate_keys(style_map) do
      :ok ->
        :ok

      {:error, invalid_keys} ->
        raise ArgumentError,
              "Invalid view transition key: #{inspect(invalid_keys)}. " <>
                "Valid keys are: #{inspect(LiveStyle.ViewTransitionClass.valid_atom_keys())} (atoms) " <>
                "or #{inspect(LiveStyle.ViewTransitionClass.valid_string_keys())} (strings)"
    end

    # Define view transition and store in manifest, get entry back
    {^name, entry} = LiveStyle.ViewTransitionClass.define(module, name, evaluated_styles)

    # Store in module attribute IMMEDIATELY during macro expansion
    Module.put_attribute(module, :__live_style_view_transition_classes__, {name, entry})

    quote do
      :ok
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
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated view_transition_classes (already a list due to accumulate: true)
    vt_list = Module.get_attribute(caller_module, :__live_style_view_transition_classes__) || []

    case List.keyfind(vt_list, ref, 0) do
      {^ref, entry} ->
        Keyword.fetch!(entry, :ident)

      nil ->
        raise CompileError,
          description:
            "View transition class :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `view_transition :#{ref}, ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  # Cross-module reference: view_transition_class({Module, :name})
  defmacro view_transition_class({module_ast, name}) when is_atom(name) do
    # Cross-module: call module.__live_style__(:view_transition_class, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    case module.__live_style__(:view_transition_class, name) do
      nil ->
        raise CompileError,
          description:
            "View transition class :#{name} not found in #{inspect(module)}. " <>
              "Make sure `view_transition :#{name}, ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      entry ->
        Keyword.fetch!(entry, :ident)
    end
  end

  @doc """
  Defines a style class with CSS declarations.

  ## Static classes

      class :button,
        display: "flex",
        padding: "8px 16px"

  ## With variable references

      class :themed,
        color: var({MyAppWeb.Tokens, :white})

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
    # Store in module attribute for processing in @before_compile
    # This defers manifest writes to reduce lock contention
    file = __CALLER__.file
    line = __CALLER__.line

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.Utils.validate_keyword_list!(declarations_evaluated)

      # Store for batch processing in @before_compile
      @__live_style_classes__ {unquote(name), normalized,
                               [file: unquote(file), line: unquote(line)]}
    end
  end

  # Static class with map syntax - class(:name, %{...})
  # This will fail with validate_keyword_list! - maps are not supported
  defmacro class(name, {:%{}, _, _} = declarations) when is_atom(name) do
    file = __CALLER__.file
    line = __CALLER__.line

    quote do
      declarations_evaluated = unquote(declarations)
      normalized = LiveStyle.Utils.validate_keyword_list!(declarations_evaluated)

      # Store for batch processing in @before_compile
      @__live_style_classes__ {unquote(name), normalized,
                               [file: unquote(file), line: unquote(line)]}
    end
  end

  # Dynamic class - function that returns declarations
  # class :dynamic_opacity, fn opacity -> [opacity: opacity] end
  defmacro class(name, {:fn, _, [{:->, _, [params, body]}]} = func) when is_atom(name) do
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
      # Generate a function that computes the declarations at runtime
      # This function calls the original lambda with the provided values
      @doc false
      def unquote(compute_fn_name)(values) do
        func = unquote(func)
        apply(func, values)
      end

      # Store for batch processing in @before_compile
      # Dynamic classes are marked with {:__dynamic__, ...}
      @__live_style_classes__ {unquote(name),
                               {:__dynamic__, unquote(Macro.escape(all_props)),
                                unquote(has_computed)}}
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
    # Evaluate overrides at compile time
    {evaluated_overrides, _} = Code.eval_quoted(overrides, [], __CALLER__)
    module = __CALLER__.module

    # Define theme and store in manifest, get entry back
    {^name, entry} = LiveStyle.ThemeClass.define(module, name, evaluated_overrides)

    # Store in module attribute IMMEDIATELY during macro expansion
    Module.put_attribute(module, :__live_style_theme_classes__, {name, entry})

    quote do
      :ok
    end
  end

  @doc """
  References a theme, returning the class name.

  ## Local reference

      theme_class(:dark)

  ## Cross-module reference

      theme_class({MyAppWeb.Tokens, :dark})
  """
  defmacro theme_class(ref) when is_atom(ref) do
    # Local reference: look up from module attributes (still compiling)
    caller_module = __CALLER__.module

    # Get accumulated theme_classes (already a list due to accumulate: true)
    theme_classes_list = Module.get_attribute(caller_module, :__live_style_theme_classes__) || []

    case List.keyfind(theme_classes_list, ref, 0) do
      {^ref, entry} ->
        Keyword.fetch!(entry, :ident)

      nil ->
        raise CompileError,
          description:
            "Theme class :#{ref} not found in #{inspect(caller_module)}. " <>
              "Make sure `theme :#{ref}, ...` is defined before this reference.",
          file: __CALLER__.file,
          line: __CALLER__.line
    end
  end

  defmacro theme_class({module_ast, name}) when is_atom(name) do
    # Cross-module: call module.__live_style__(:theme_class, name) directly
    # This creates an automatic compile-time dependency - no require needed!
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    case module.__live_style__(:theme_class, name) do
      nil ->
        raise CompileError,
          description:
            "Theme class :#{name} not found in #{inspect(module)}. " <>
              "Make sure `theme :#{name}, ...` is defined in that module.",
          file: __CALLER__.file,
          line: __CALLER__.line

      entry ->
        Keyword.fetch!(entry, :ident)
    end
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

      # Local marker (same module)
      marker(:row)

      # Cross-module marker
      marker({OtherModule, :row})

  ## Usage

      <tr class={marker(:row)}>
        <td {css(:cell)}>...</td>
      </tr>
  """
  defmacro marker(name) when is_atom(name) do
    module = __CALLER__.module

    quote do
      LiveStyle.Marker.ref({unquote(module), unquote(name)})
    end
  end

  defmacro marker({module_ast, name}) when is_atom(name) do
    {module, _} = Code.eval_quoted(module_ast, [], __CALLER__)

    quote do
      LiveStyle.Marker.ref({unquote(module), unquote(name)})
    end
  end
end
