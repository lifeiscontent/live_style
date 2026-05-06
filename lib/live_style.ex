defmodule LiveStyle do
  @moduledoc """
  LiveStyle - Compile-time CSS-in-Elixir for Phoenix LiveView.

  Static style references resolve to deterministic class payloads at compile time.
  Dynamic classes and forward references use a small runtime attribute payload so
  component spreads can preserve last-wins merging semantics without manifest
  lookups during render.

  ## Basic Usage

      defmodule MyAppWeb.Button do
        use Phoenix.Component
        use LiveStyle

        # Define CSS variables
        vars primary: "#3b82f6",
             white: "#ffffff"

        # Define a theme that overrides variables
        theme_class :dark,
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
  - `view_transition_class({Module, :name})` - Reference a view transition

  Local references (within the same module):
  - `var(:name)`
  - `keyframes(:name)`
  - `theme_class(:name)`

  ## Public API Functions

  - `LiveStyle.default_marker/0` - Get the default marker for contextual selectors
  - `LiveStyle.marker/1` - Get a custom marker

  See the README for comprehensive documentation and examples.
  """

  alias LiveStyle.Compiler.ModuleData
  alias LiveStyle.Runtime.StyleMerger

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
    Module.register_attribute(module, :__live_style_usage__, accumulate: true)

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
          theme_class: 2,
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
          css_class: 1,
          # Composition
          include: 1,
          # Utilities
          fallback: 1,
          # Markers for contextual selectors (When)
          default_marker: 0,
          marker: 1
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
    alias LiveStyle.Compiler.ModuleHash

    # Get all accumulated entries for hash computation
    vars = Module.get_attribute(env.module, :__live_style_vars__) || []
    consts = Module.get_attribute(env.module, :__live_style_consts__) || []
    keyframes = Module.get_attribute(env.module, :__live_style_keyframes__) || []
    theme_classes = Module.get_attribute(env.module, :__live_style_theme_classes__) || []

    view_transition_classes =
      Module.get_attribute(env.module, :__live_style_view_transition_classes__) || []

    position_try = Module.get_attribute(env.module, :__live_style_position_try__) || []

    # Compute module hash for __mix_recompile__? detection
    module_hash =
      ModuleHash.compute(
        module,
        classes,
        vars,
        consts,
        keyframes,
        theme_classes,
        view_transition_classes,
        position_try
      )

    # Build a local manifest for this module's classes (no file I/O, no locks)
    # This eliminates lock contention during parallel compilation
    local_manifest = LiveStyle.Manifest.empty()

    # Define all static classes in local manifest
    local_manifest =
      Enum.reduce(static_classes, local_manifest, fn class_entry, acc ->
        {name, declarations, opts} = BeforeCompile.normalize_class_entry(class_entry)
        Class.batch_define(acc, module, name, declarations, opts)
      end)

    # Define all dynamic classes in local manifest
    local_manifest =
      Enum.reduce(dynamic_classes, local_manifest, fn {name,
                                                       {:__dynamic__, all_props, _has_computed}},
                                                      acc ->
        Class.batch_define_dynamic(acc, module, name, all_props)
      end)

    # Write module data to per-module file (no lock needed - each module has its own file)
    alias LiveStyle.Compiler.ModuleData

    usage =
      env.module
      |> Module.get_attribute(:__live_style_usage__, [])
      |> MapSet.new()

    ModuleData.write(module, %{
      module: module,
      source: env.file,
      source_fingerprint: ModuleData.source_fingerprint(env.file),
      module_hash: module_hash,
      vars: vars,
      consts: consts,
      keyframes: keyframes,
      theme_classes: theme_classes,
      view_transition_classes: view_transition_classes,
      position_try: position_try,
      classes: local_manifest.classes
    })

    ModuleData.write_usage(module, usage)

    # Use local manifest to build class maps (no file read needed)
    manifest = local_manifest

    # Build class_strings and property_classes for ALL classes (static + dynamic)
    # This matches StyleX behavior where dynamic classes also have property-based merging
    all_classes = static_classes ++ dynamic_classes

    {class_strings, property_classes} =
      BeforeCompile.build_class_maps(all_classes, module, manifest)

    # Generate dynamic class functions (only compute var_list at runtime)
    dynamic_fns = BeforeCompile.build_dynamic_fns(dynamic_classes, module)

    dynamic_names = Enum.map(dynamic_classes, fn {name, _} -> name end)

    # Build maps from already-fetched entries (fetched earlier for hash computation)
    vars_map = Map.new(vars)
    consts_map = Map.new(consts)
    keyframes_map = Map.new(keyframes)
    theme_classes_map = Map.new(theme_classes)
    view_transition_classes_map = Map.new(view_transition_classes)
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
      # Store the module hash computed at compile time for recompilation detection
      # Note: We intentionally do NOT use @external_resource for the manifest file
      # because the manifest is written AFTER modules compile (by the :live_style compiler),
      # which would cause infinite recompilation loops.
      @__live_style_module_hash__ unquote(module_hash)

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
      def __mix_recompile__? do
        # Check if the stored hash in the manifest matches our compile-time hash
        # Returns true if we need to recompile (hash missing or different)
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        stored = LiveStyle.Compiler.ModuleHash.get_stored_hash(__MODULE__)
        stored == nil or @__live_style_module_hash__ != stored
      end

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
  References a CSS variable, returning a `var(--<prefix><hash>)` reference.

  When used as a value, returns a `var(...)` reference for CSS variables.
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

      consts breakpoint_sm: "(max-width: 640px)",
             breakpoint_lg: "(min-width: 1025px)",
             z_modal: "50",
             z_tooltip: "100"
  """
  defmacro consts(consts_list) do
    # Evaluate consts at compile time so they're available for const references
    {evaluated_consts, _} = Code.eval_quoted(consts_list, [], __CALLER__)
    module = __CALLER__.module

    # Store in manifest (for CSS generation) and get entries back
    entries = LiveStyle.Consts.define(evaluated_consts)

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
    {^name, entry} = LiveStyle.Keyframes.define(name, evaluated_frames)

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
    {^name, entry} = LiveStyle.PositionTry.define(name, normalized_values)

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
    {evaluated, _} = Code.eval_quoted(declarations, [], __CALLER__)
    normalized = LiveStyle.Utils.validate_keyword_list!(evaluated)

    # Validate and normalize declarations
    case LiveStyle.PositionTry.validate_declarations(normalized) do
      {:ok, normalized_values} ->
        LiveStyle.PositionTry.define_anonymous(normalized_values)

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
    {^name, entry} = LiveStyle.ViewTransitionClass.define(name, evaluated_styles)

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
              "Make sure `view_transition_class :#{ref}, ...` is defined before this reference.",
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
              "Make sure `view_transition_class :#{name}, ...` is defined in that module.",
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

  When all references can be resolved at compile time, returns a literal
  keyword list with a precomputed class payload, avoiding runtime class merging
  for static references.

  Falls back to `%LiveStyle.Attrs{}` at runtime for forward references,
  dynamic args, or non-literal style values.

  ## Examples

      # Single ref (static — class in Rendered.static)
      <div {css(:button)}>

      # List of refs with conditionals (branch-optimized)
      <div {css([:base, @active && :active])}>

      # Dynamic styles (runtime fallback)
      <div {css([{:dynamic_color, @color}])}>

      # With additional inline styles (static class, dynamic style value)
      <div {css([:card], style: [view_transition_name: "card-1"])}>

      # With view transitions
      <div {css([:card], style: [
        view_transition_class: view_transition_class(:card),
        view_transition_name: "card-\#{@id}"
      ])}>
  """
  # Single atom reference: css(:button)
  # Computes class string at compile time for statics optimization (PR #4145)
  defmacro css(name) when is_atom(name) do
    caller_module = __CALLER__.module

    # Record usage at compile time for tree shaking
    record_class_usage(caller_module, caller_module, name)

    if all_static_refs?([name], __CALLER__) do
      case compute_static_class_string(caller_module, name) do
        {:ok, class_string} ->
          prop_classes = static_prop_classes_source(caller_module, [name], __CALLER__)
          Macro.escape(build_static_attr_list(class_string, nil, prop_classes))

        :error ->
          quote do
            LiveStyle.resolve_attrs(__MODULE__, [unquote(name)], nil)
          end
      end
    else
      # Class not found yet (forward reference) — fall back to runtime
      quote do
        LiveStyle.resolve_attrs(__MODULE__, [unquote(name)], nil)
      end
    end
  end

  # List of refs: css([:base, :primary, @active && :active])
  # Static atoms are resolved at compile time; dynamic expressions use runtime
  defmacro css(refs) when is_list(refs) do
    caller_module = __CALLER__.module

    # Extract and record all static class refs at compile time
    extract_class_refs(refs, caller_module, __CALLER__)
    |> Enum.each(fn {defining_mod, class_name} ->
      record_class_usage(caller_module, defining_mod, class_name)
    end)

    if all_static_refs?(refs, __CALLER__) do
      {class_string, style_string, _prop_classes} =
        compute_static_attrs!(caller_module, refs, __CALLER__)

      prop_classes = static_prop_classes_source(caller_module, refs, __CALLER__)
      Macro.escape(build_static_attr_list(class_string, style_string, prop_classes))
    else
      case try_branch_optimization(refs, __CALLER__) do
        :error ->
          quote do
            LiveStyle.resolve_attrs(__MODULE__, unquote(refs), nil)
          end

        result ->
          build_branch_optimized_ast(result, caller_module, __CALLER__)
      end
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
    caller_module = __CALLER__.module

    # Extract and record all static class refs at compile time
    # Handle both single ref and list of refs
    refs_list = if is_list(refs), do: refs, else: [refs]

    extract_class_refs(refs_list, caller_module, __CALLER__)
    |> Enum.each(fn {defining_mod, class_name} ->
      record_class_usage(caller_module, defining_mod, class_name)
    end)

    cond do
      all_static_refs?(refs_list, __CALLER__) and static_style_opts?(opts, __CALLER__) ->
        {class_string, dynamic_style_string, _prop_classes} =
          compute_static_attrs!(caller_module, refs_list, __CALLER__)

        extra_style = compute_static_extra_styles(opts, __CALLER__)
        style_string = merge_style_strings(dynamic_style_string, extra_style)

        prop_classes = static_prop_classes_source(caller_module, refs_list, __CALLER__)
        Macro.escape(build_static_attr_list(class_string, style_string, prop_classes))

      static_style_opts?(opts, __CALLER__) ->
        try_branch_with_style_opts(refs_list, refs, opts, caller_module, __CALLER__)

      true ->
        quote do
          LiveStyle.resolve_attrs(__MODULE__, unquote(refs), unquote(opts))
        end
    end
  end

  @doc """
  Returns just the CSS class string for a style reference.

  Useful when you need the class string directly, such as with `Phoenix.LiveView.JS`:

      JS.transition(css_class(:toast_hiding), to: "#\#{id}", time: 200)

  Unlike `css/1` which returns attributes for template spreading,
  `css_class/1` returns a plain class string for use in JS commands:

      JS.transition(css_class(:toast_hiding), to: "#\#{id}")

  ## Cross-module references

  Use a tuple to reference styles from another module:

      JS.add_class(css_class({SharedStyles, :highlight}), to: "#target")
  """
  defmacro css_class(name) when is_atom(name) do
    caller_module = __CALLER__.module
    record_class_usage(caller_module, caller_module, name)

    quote do
      Keyword.get(__MODULE__.__live_style__(:class_strings), unquote(name), "")
    end
  end

  defmacro css_class({module, name}) when is_atom(module) and is_atom(name) do
    caller_module = __CALLER__.module
    record_class_usage(caller_module, module, name)

    quote do
      Keyword.get(unquote(module).__live_style__(:class_strings), unquote(name), "")
    end
  end

  # Records a class usage for tree shaking (per-module file, no locking)
  # 2-arg version for backwards compatibility (assumes consuming == defining)
  @doc false
  def record_class_usage(defining_module, class_name)
      when is_atom(defining_module) and is_atom(class_name) do
    record_class_usage(defining_module, defining_module, class_name)
  end

  # 3-arg version with explicit consuming module
  @doc false
  def record_class_usage(consuming_module, defining_module, class_name)
      when is_atom(consuming_module) and is_atom(defining_module) and is_atom(class_name) do
    usage = {defining_module, class_name}

    if accumulate_class_usage(consuming_module, usage) do
      :ok
    else
      ModuleData.record_usage(consuming_module, defining_module, class_name)
    end
  end

  defp accumulate_class_usage(module, usage) do
    if Module.open?(module) and Module.has_attribute?(module, :__live_style_usage__) do
      Module.put_attribute(module, :__live_style_usage__, usage)
      true
    else
      false
    end
  rescue
    ArgumentError -> false
  end

  # Extracts static class references from a list of refs (for usage tracking)
  # Returns list of {module, class_name} tuples
  @doc false
  def extract_class_refs(refs, caller_module, caller) when is_list(refs) do
    context = %{caller_module: caller_module, caller: caller}

    refs
    |> Enum.flat_map(fn ref -> extract_single_ref(ref, context) end)
    |> Enum.uniq()
  end

  defp extract_single_ref(ref, context) do
    case ref do
      class_name when is_atom(class_name) ->
        local_ref(class_name, context.caller_module)

      {module, class_name} when is_atom(module) and is_atom(class_name) ->
        cross_module_ref(module, class_name)

      {class_name, _value} when is_atom(class_name) ->
        local_ref(class_name, context.caller_module)

      ast ->
        extract_refs_from_ast(ast, context.caller_module, context.caller)
    end
  end

  defp local_ref(class_name, caller_module), do: [{caller_module, class_name}]

  defp cross_module_ref(module, class_name) do
    [{module, class_name}]
  end

  defp extract_refs_from_ast(ast, caller_module, caller) do
    # Complex expression like @active && :primary
    # Use Macro.prewalk to find all atom literals (potential class refs)
    {_, refs} =
      Macro.prewalk(ast, [], fn
        # Atom literals that could be class names
        name, acc when is_atom(name) and name not in [nil, true, false] ->
          # Skip common Elixir special atoms
          if atom_is_class_name?(name) do
            {name, [{caller_module, name} | acc]}
          else
            {name, acc}
          end

        # Cross-module tuple refs inside expressions
        {{:__aliases__, _, _} = module_ast, class_name} = node, acc
        when is_atom(class_name) ->
          case Macro.expand(module_ast, caller) do
            module when is_atom(module) ->
              {node, [{module, class_name} | acc]}

            _ ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    refs
  end

  # Check if an atom looks like a class name (not a special form or operator)
  defp atom_is_class_name?(atom) do
    name = Atom.to_string(atom)
    # Class names are lowercase identifiers, not operators or special forms
    String.match?(name, ~r/^[a-z_][a-zA-Z0-9_]*$/)
  end

  # ============================================================================
  # Compile-time class string computation (statics optimization)
  # ============================================================================

  # Check if all refs in a list can be resolved at compile time.
  # Static refs are:
  #   - Atoms (local refs): :button
  #   - Cross-module tuples: {OtherModule, :button} (alias AST + atom)
  #   - Dynamic class tuples with literal args: {:opacity, 0.5} or {:size, ["100px", "200px"]}
  @doc false
  def all_static_refs?(refs, caller) do
    classes = Module.get_attribute(caller.module, :__live_style_classes__) || []

    Enum.all?(refs, fn
      ref when is_atom(ref) ->
        # Check that the class is already defined (not a forward reference)
        class_defined?(ref, classes)

      {{:__aliases__, _, _} = module_ast, class_name} when is_atom(class_name) ->
        case Macro.expand(module_ast, caller) do
          module when is_atom(module) ->
            # Verify the class exists in the target module
            Code.ensure_loaded(module)

            function_exported?(module, :__live_style__, 1) and
              Keyword.has_key?(module.__live_style__(:property_classes), class_name)

          _ ->
            false
        end

      {class_name, args} when is_atom(class_name) ->
        literal_value?(args) and class_defined?(class_name, classes) and
          static_dynamic_class?(class_name, classes)

      _ ->
        false
    end)
  end

  # Try to optimize a refs list that contains conditional patterns.
  # Handles &&, if/else, case, and cond where all branch bodies are static atoms.
  # Supports multiple conditionals (e.g., two && expressions) by enumerating
  # all combinations. Limited to 16 total leaf branches to avoid exponential blowup.
  # Returns {:ok, refs} or :error.
  defp try_branch_optimization(refs, caller) do
    branch_count = count_total_branches(refs)

    if branch_count > 1 and branch_count <= 16 do
      combinations = enumerate_combinations(refs)

      if Enum.all?(combinations, &all_static_refs?(&1, caller)) do
        {:ok, refs}
      else
        :error
      end
    else
      :error
    end
  end

  # Count total leaf branches from all conditional elements in refs.
  # Product of individual branch counts (e.g., 2 &&'s = 2 × 2 = 4).
  defp count_total_branches(refs) do
    Enum.reduce(refs, 1, fn ref, acc -> acc * branch_count(ref) end)
  end

  defp branch_count({:&&, _, [_, r]}) when is_atom(r), do: 2
  defp branch_count({:if, _, [_, [do: d, else: e]]}) when is_atom(d) and is_atom(e), do: 2

  defp branch_count({:case, _, [_, [do: clauses]]}) when is_list(clauses) do
    if all_clause_bodies_atoms?(clauses), do: length(clauses), else: 1
  end

  defp branch_count({:cond, _, [[do: clauses]]}) when is_list(clauses) do
    if all_clause_bodies_atoms?(clauses), do: length(clauses), else: 1
  end

  defp branch_count(_), do: 1

  defp all_clause_bodies_atoms?(clauses) do
    Enum.all?(clauses, fn
      {:->, _, [_, body]} when is_atom(body) -> true
      _ -> false
    end)
  end

  # Enumerate all possible leaf ref lists by expanding each conditional.
  # For css([:a, c1 && :b, c2 && :c]) → [[:a, :b, :c], [:a, :b], [:a, :c], [:a]]
  defp enumerate_combinations(refs) do
    case find_first_conditional(refs) do
      nil ->
        [refs]

      {_idx, branches} ->
        branches
        |> Enum.flat_map(&enumerate_combinations/1)
        |> Enum.take(16)
    end
  end

  # Find the first conditional element in refs and return its branch expansions.
  # Returns {idx, [branch_refs_list, ...]} or nil.
  defp find_first_conditional(refs) do
    refs
    |> Enum.with_index()
    |> Enum.find_value(fn
      {{:&&, _, [_, ref]}, idx} when is_atom(ref) ->
        {idx, [List.replace_at(refs, idx, ref), List.delete_at(refs, idx)]}

      {{:if, _, [_, [do: d, else: e]]}, idx} when is_atom(d) and is_atom(e) ->
        {idx, [List.replace_at(refs, idx, d), List.replace_at(refs, idx, e)]}

      {{:case, _, [_, [do: clauses]]}, idx} when is_list(clauses) ->
        expand_clause_branches(clauses, refs, idx)

      {{:cond, _, [[do: clauses]]}, idx} when is_list(clauses) ->
        expand_clause_branches(clauses, refs, idx)

      _ ->
        nil
    end)
  end

  defp expand_clause_branches(clauses, refs, idx) do
    if all_clause_bodies_atoms?(clauses) do
      branches = Enum.map(clauses, fn {:->, _, [_, body]} -> List.replace_at(refs, idx, body) end)
      {idx, branches}
    end
  end

  # Build quoted AST for branch-optimized conditionals.
  # Recursively processes each conditional element, generating nested branching.
  # Optional style_fn merges extra style opts into each leaf's dynamic style.
  defp build_branch_optimized_ast({:ok, refs}, caller_module, caller, style_fn \\ nil) do
    build_recursive_branches(refs, caller_module, caller, style_fn)
  end

  defp build_recursive_branches(refs, caller_module, caller, style_fn) do
    case find_first_conditional_with_info(refs) do
      nil ->
        # Base case: all refs are static atoms — compute attrs
        {c, s, _prop_classes} = compute_static_attrs!(caller_module, refs, caller)
        style = if style_fn, do: style_fn.(s), else: s
        prop_classes = static_prop_classes_source(caller_module, refs, caller)
        Macro.escape(build_static_attr_list(c, style, prop_classes))

      {idx, {:and, condition, ref}} ->
        truthy =
          build_recursive_branches(
            List.replace_at(refs, idx, ref),
            caller_module,
            caller,
            style_fn
          )

        falsy =
          build_recursive_branches(
            List.delete_at(refs, idx),
            caller_module,
            caller,
            style_fn
          )

        quote do
          if unquote(condition), do: unquote(truthy), else: unquote(falsy)
        end

      {idx, {:if_else, condition, do_ref, else_ref}} ->
        truthy =
          build_recursive_branches(
            List.replace_at(refs, idx, do_ref),
            caller_module,
            caller,
            style_fn
          )

        falsy =
          build_recursive_branches(
            List.replace_at(refs, idx, else_ref),
            caller_module,
            caller,
            style_fn
          )

        quote do
          if unquote(condition), do: unquote(truthy), else: unquote(falsy)
        end

      {idx, {:case_expr, meta, subject, clauses}} ->
        optimized_clauses =
          Enum.map(clauses, fn {patterns, clause_meta, body} ->
            branch =
              build_recursive_branches(
                List.replace_at(refs, idx, body),
                caller_module,
                caller,
                style_fn
              )

            {:->, clause_meta, [patterns, branch]}
          end)

        {:case, meta, [subject, [do: optimized_clauses]]}

      {idx, {:cond_expr, meta, clauses}} ->
        optimized_clauses =
          Enum.map(clauses, fn {conditions, clause_meta, body} ->
            branch =
              build_recursive_branches(
                List.replace_at(refs, idx, body),
                caller_module,
                caller,
                style_fn
              )

            {:->, clause_meta, [conditions, branch]}
          end)

        {:cond, meta, [[do: optimized_clauses]]}
    end
  end

  # Find the first conditional and return structured info for AST generation.
  defp find_first_conditional_with_info(refs) do
    refs
    |> Enum.with_index()
    |> Enum.find_value(fn
      {{:&&, _, [condition, ref]}, idx} when is_atom(ref) ->
        {idx, {:and, condition, ref}}

      {{:if, _, [condition, [do: d, else: e]]}, idx} when is_atom(d) and is_atom(e) ->
        {idx, {:if_else, condition, d, e}}

      {{:case, meta, [subject, [do: clauses]]}, idx} when is_list(clauses) ->
        expand_case_clause_info(clauses, idx, meta, subject)

      {{:cond, meta, [[do: clauses]]}, idx} when is_list(clauses) ->
        expand_cond_clause_info(clauses, idx, meta)

      _ ->
        nil
    end)
  end

  defp expand_case_clause_info(clauses, idx, meta, subject) do
    if all_clause_bodies_atoms?(clauses) do
      clause_info = Enum.map(clauses, fn {:->, cm, [p, body]} -> {p, cm, body} end)
      {idx, {:case_expr, meta, subject, clause_info}}
    end
  end

  defp expand_cond_clause_info(clauses, idx, meta) do
    if all_clause_bodies_atoms?(clauses) do
      clause_info = Enum.map(clauses, fn {:->, cm, [conds, body]} -> {conds, cm, body} end)
      {idx, {:cond_expr, meta, clause_info}}
    end
  end

  # Build a keyword list of static attributes from pre-computed class and style strings.
  defp build_static_attr_list(class_string, style_string, prop_classes) do
    %LiveStyle.Attrs{class: class_string, style: style_string, prop_classes: prop_classes}
    |> LiveStyle.Attrs.to_list()
  end

  defp static_prop_classes_source(caller_module, refs, caller) do
    {:live_style_static_refs, caller_module, Enum.map(refs, &normalize_static_ref(&1, caller))}
  end

  defp normalize_static_ref({{:__aliases__, _meta, _parts} = module_ast, class_name}, caller)
       when is_atom(class_name) do
    {Macro.expand(module_ast, caller), class_name}
  end

  defp normalize_static_ref(ref, _caller), do: ref

  # Check if a class name has been defined in the accumulated classes so far.
  defp class_defined?(name, classes) do
    Enum.any?(classes, fn
      {^name, _} -> true
      {^name, _, _} -> true
      _ -> false
    end)
  end

  # Check if a dynamic class with args can be resolved at compile time.
  # Only allows simple property mapping (has_computed=false), not computed bodies.
  defp static_dynamic_class?(class_name, classes) do
    case Enum.find(classes, fn
           {^class_name, {:__dynamic__, _, _}} -> true
           _ -> false
         end) do
      {_, {:__dynamic__, _all_props, has_computed}} -> not has_computed
      nil -> true
    end
  end

  # Try branch optimization with style opts for css/2.
  defp try_branch_with_style_opts(refs_list, refs, opts, caller_module, caller) do
    case try_branch_optimization(refs_list, caller) do
      :error ->
        quote do
          LiveStyle.resolve_attrs(__MODULE__, unquote(refs), unquote(opts))
        end

      result ->
        extra_style = compute_static_extra_styles(opts, caller)

        build_branch_optimized_ast(result, caller_module, caller, fn dynamic_style ->
          merge_style_strings(dynamic_style, extra_style)
        end)
    end
  end

  # Check if a value is a compile-time literal (not an AST expression)
  defp literal_value?(value) when is_binary(value), do: true
  defp literal_value?(value) when is_number(value), do: true
  defp literal_value?(value) when is_atom(value), do: true
  defp literal_value?(values) when is_list(values), do: Enum.all?(values, &literal_value?/1)
  defp literal_value?(_), do: false

  # Check if style opts are all compile-time literals.
  # Expands nested macros (e.g., view_transition_class(:card)) before checking.
  # Accepts opts like [style: [opacity: "0.5", view_transition_class: view_transition_class(:card)]]
  defp static_style_opts?(opts, caller) when is_list(opts) do
    case Keyword.get(opts, :style) do
      nil ->
        true

      styles when is_list(styles) ->
        Enum.all?(styles, fn
          {key, value} when is_atom(key) or is_binary(key) ->
            expanded = Macro.expand(value, caller)
            literal_value?(expanded)

          _ ->
            false
        end)

      style when is_binary(style) ->
        true

      _ ->
        false
    end
  end

  # Compute extra styles from static opts at compile time.
  # Expands nested macros in style values before formatting.
  # Mirrors the runtime format_extra_styles logic.
  defp compute_static_extra_styles(opts, caller) do
    case Keyword.get(opts, :style) do
      nil ->
        nil

      styles when is_list(styles) ->
        Enum.map_join(styles, "; ", fn {key, value} ->
          format_style_declaration(key, Macro.expand(value, caller))
        end)

      style when is_binary(style) ->
        style
    end
  end

  defp format_style_declaration(key, value) when is_atom(key) do
    "#{LiveStyle.CSSValue.to_css_property(key)}: #{value}"
  end

  defp format_style_declaration(key, value), do: "#{key}: #{value}"

  # Merge dynamic class var styles with extra style opts.
  defp merge_style_strings(dynamic, extra) do
    StyleMerger.merge_style_strings(dynamic, extra)
  end

  # Compute class string for a single local atom ref at compile time.
  # Returns {:ok, class_string} or :error if the class isn't found yet
  # (forward reference — class defined later in the module).
  @doc false
  def compute_static_class_string(caller_module, name) do
    cache = get_or_build_static_cache(caller_module)

    case Keyword.fetch(cache.class_strings, name) do
      {:ok, class_string} ->
        {:ok, class_string}

      :error ->
        :error
    end
  end

  # Compute merged attrs (class string + optional style) for a list of static refs.
  # Handles local atoms, cross-module refs, and dynamic refs with literal args.
  # Returns {class_string, style_string | nil, prop_classes}.
  @doc false
  def compute_static_attrs!(caller_module, refs, caller) do
    alias LiveStyle.Runtime.StyleMerger

    cache = get_or_build_static_cache(caller_module)

    context = %{caller_module: caller_module, cache: cache, caller: caller}

    attrs =
      refs
      |> Enum.map(&resolve_static_ref!(&1, context))
      |> StyleMerger.merge_resolved_refs()

    {attrs.class, attrs.style, attrs.prop_classes}
  end

  defp resolve_static_ref!(name, %{
         caller_module: caller_module,
         cache: cache,
         caller: caller
       })
       when is_atom(name) do
    name
    |> fetch_local_static_ref!(caller_module, cache, caller)
    |> to_resolved_static_ref()
  end

  defp resolve_static_ref!(
         {{:__aliases__, _, _} = module_ast, class_name},
         %{caller: caller}
       )
       when is_atom(class_name) do
    module_ast
    |> fetch_cross_module_static_ref!(class_name, caller)
    |> to_resolved_static_ref()
  end

  defp resolve_static_ref!(
         {class_name, args},
         %{caller_module: caller_module, cache: cache, caller: caller}
       )
       when is_atom(class_name) do
    class_name
    |> fetch_dynamic_static_ref!(args, caller_module, cache, caller)
    |> to_resolved_static_ref()
  end

  defp to_resolved_static_ref(ref_data) do
    case ref_data do
      {prop_classes, nil} -> {:static, prop_classes}
      {prop_classes, var_list} -> {:dynamic, prop_classes, var_list}
    end
  end

  defp fetch_local_static_ref!(class_name, caller_module, cache, caller) do
    prop_classes =
      fetch_local_prop_classes!(
        class_name,
        caller_module,
        cache.property_classes,
        caller
      )

    {prop_classes, nil}
  end

  defp fetch_cross_module_static_ref!(module_ast, class_name, caller) do
    module = Macro.expand(module_ast, caller)

    case Keyword.fetch(module.__live_style__(:property_classes), class_name) do
      {:ok, prop_classes} ->
        {prop_classes, nil}

      :error ->
        raise CompileError,
          description:
            "Class :#{class_name} not found in #{inspect(module)}. " <>
              "Make sure `class :#{class_name}, ...` is defined in that module.",
          file: caller.file,
          line: caller.line
    end
  end

  defp fetch_dynamic_static_ref!(class_name, args, caller_module, cache, caller) do
    prop_classes =
      fetch_local_prop_classes!(
        class_name,
        caller_module,
        cache.property_classes,
        caller
      )

    if class_name in cache.dynamic_names do
      {^class_name, {:__dynamic__, all_props, has_computed}} =
        Enum.find(cache.dynamic_classes, fn
          {^class_name, {:__dynamic__, _, _}} -> true
          _ -> false
        end)

      args_list = if is_list(args), do: args, else: [args]

      alias LiveStyle.Runtime.Dynamic

      var_list =
        Dynamic.compute_var_list(
          all_props,
          args_list,
          caller_module,
          class_name,
          has_computed
        )

      {prop_classes, var_list}
    else
      # Not a dynamic class — just use as static (like bare atom with ignored args)
      {prop_classes, nil}
    end
  end

  defp fetch_local_prop_classes!(class_name, caller_module, property_classes, caller) do
    case Keyword.fetch(property_classes, class_name) do
      {:ok, prop_classes} ->
        prop_classes

      :error ->
        raise CompileError,
          description:
            "Class :#{class_name} not found in #{inspect(caller_module)}. " <>
              "Make sure `class :#{class_name}, ...` is defined before this reference.",
          file: caller.file,
          line: caller.line
    end
  end

  # Build a local manifest from accumulated class definitions.
  # Reuses the same pipeline as __before_compile__.
  defp build_local_manifest(classes, module) do
    alias LiveStyle.Class
    alias LiveStyle.Compiler.BeforeCompile

    classes_reversed = Enum.reverse(classes)

    {static_classes, dynamic_classes} = split_class_entries(classes_reversed)

    manifest = LiveStyle.Manifest.empty()

    manifest =
      Enum.reduce(static_classes, manifest, fn class_entry, acc ->
        {name, declarations, opts} = BeforeCompile.normalize_class_entry(class_entry)
        Class.batch_define(acc, module, name, declarations, opts)
      end)

    Enum.reduce(dynamic_classes, manifest, fn
      {name, {:__dynamic__, all_props, _has_computed}}, acc ->
        Class.batch_define_dynamic(acc, module, name, all_props)
    end)
  end

  defp get_or_build_static_cache(module) do
    classes = Module.get_attribute(module, :__live_style_classes__) || []
    class_count = length(classes)

    case Module.get_attribute(module, :__live_style_static_cache__) do
      {^class_count, cache} ->
        cache

      _ ->
        cache = build_static_cache(classes, module)
        Module.put_attribute(module, :__live_style_static_cache__, {class_count, cache})
        cache
    end
  end

  defp build_static_cache(classes, module) do
    alias LiveStyle.Compiler.BeforeCompile

    classes_reversed = Enum.reverse(classes)
    {static_classes, dynamic_classes} = split_class_entries(classes_reversed)
    manifest = build_local_manifest(classes, module)
    all_classes = static_classes ++ dynamic_classes

    {class_strings, property_classes} =
      BeforeCompile.build_class_maps(all_classes, module, manifest)

    %{
      manifest: manifest,
      class_strings: class_strings,
      property_classes: property_classes,
      dynamic_classes: dynamic_classes,
      dynamic_names: Enum.map(dynamic_classes, fn {name, _} -> name end)
    }
  end

  defp split_class_entries(classes) do
    Enum.split_with(classes, fn
      {_name, {:__dynamic__, _, _}} -> false
      {_name, _declarations, _opts} -> true
      {_name, decl} -> not match?({:__dynamic__, _, _}, decl)
    end)
  end

  @doc """
  Defines a theme class (variable overrides).

  Similar to StyleX's `createTheme`, this creates a class that overrides
  CSS variables defined with `vars`.

  ## Examples

      # First define your variables
      vars white: "#ffffff",
           primary: "#3b82f6"

      # Then create a theme that overrides those variables
      theme_class :dark,
        white: "#000000",
        primary: "#8ab4f8"
  """
  defmacro theme_class(name, overrides) when is_atom(name) do
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
              "Make sure `theme_class :#{ref}, ...` is defined before this reference.",
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
              "Make sure `theme_class :#{name}, ...` is defined in that module.",
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
  Returns the default marker for use with `LiveStyle.When` selectors.

  ## Example

      <div {css([default_marker()])}>
        <div {css(:card)}>Hover parent to move me</div>
      </div>
  """
  defdelegate default_marker(), to: LiveStyle.Marker, as: :default

  @doc """
  Returns a marker for use with `LiveStyle.When` selectors.

  Custom markers allow you to have multiple independent sets of contextual selectors
  in the same component tree.

  ## Examples

      # Local marker (same module)
      marker(:row)

      # Cross-module marker
      marker({OtherModule, :row})

  ## Usage

      <tr {css([marker(:row)])}>
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

  # ============================================================================
  # Phoenix Watcher Integration
  # ============================================================================

  @doc """
  Runs LiveStyle CSS generation.

  This is typically called by the mix task or the watcher. Returns 0 on success.

  ## Options

    * `--watch` - Watch for manifest changes and regenerate CSS automatically

  ## Examples

      LiveStyle.run(:default, [])
      LiveStyle.run(:default, ~w(--watch))

  """
  @spec run(atom(), [String.t()]) :: non_neg_integer()
  defdelegate run(profile \\ :default, args \\ []), to: LiveStyle.Compiler.Runner

  @doc """
  Runs LiveStyle CSS generation, installing dependencies if needed.

  This follows the same pattern as `Tailwind.install_and_run/2` and
  `Esbuild.install_and_run/2`, making it suitable for use as a Phoenix
  endpoint watcher.

  ## Setup

  Add to your `config/dev.exs`:

      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
          live_style: {LiveStyle, :install_and_run, [:default, ~w(--watch)]}
        ]

  ## Examples

      LiveStyle.install_and_run(:default, ~w(--watch))

  """
  @spec install_and_run(atom(), [String.t()]) :: non_neg_integer()
  defdelegate install_and_run(profile \\ :default, args \\ []), to: LiveStyle.Compiler.Runner
end
