defmodule LiveStyle.ViewTransitions do
  @moduledoc """
  CSS View Transitions API support for LiveStyle.

  This module follows StyleX's `viewTransitionClass` API pattern. It creates
  CSS rules for `::view-transition` pseudo-elements tied to a generated class
  name, which can be used to customize View Transition animations.

  ## Usage

      defmodule MyAppWeb.Tokens do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        # Define keyframes using LiveStyle's existing keyframes API
        defkeyframes :scale_in, %{
          from: %{opacity: "0", transform: "scale(0.8)"},
          to: %{opacity: "1", transform: "scale(1)"}
        }

        defkeyframes :scale_out, %{
          from: %{opacity: "1", transform: "scale(1)"},
          to: %{opacity: "0", transform: "scale(0.8)"}
        }

        # Define view transitions - reference keyframes by atom
        view_transition "card-*", %{
          old: %{
            animation_name: :scale_out,
            animation_duration: "250ms",
            animation_fill_mode: "both"
          },
          new: %{
            animation_name: :scale_in,
            animation_duration: "250ms",
            animation_fill_mode: "both"
          }
        }
      end

  ## Keyframe References

  When using `animation_name`, you can reference keyframes defined with `defkeyframes/2`
  using atom syntax. The atom is automatically resolved to the hashed keyframe name
  at compile time:

      defkeyframes :fade_out, %{from: %{opacity: "1"}, to: %{opacity: "0"}}

      view_transition "item-*", %{
        old: %{animation_name: :fade_out}  # Resolves to "k1a2b3c4"
      }

  ### Compile-time Validation

  LiveStyle validates that all `animation_name` atom references correspond to
  defined keyframes. If you reference an undefined keyframe, you'll get a
  compile-time error with a helpful message:

      # This will raise a CompileError:
      view_transition "item-*", %{
        old: %{animation_name: :nonexistent}
      }
      # => Undefined keyframe reference(s): :nonexistent
      #    Defined keyframes: :fade_in, :fade_out

  ### CSS Keywords

  Standard CSS keywords like `:none`, `:inherit`, `:initial`, and `:unset` are
  allowed without being defined as keyframes:

      view_transition "item-*", %{
        old: %{
          animation_name: %{
            :default => :fade_out,
            "@media (prefers-reduced-motion: reduce)" => :none  # OK!
          }
        }
      }

  ## Pseudo-element Keys

  The options map accepts these keys which map to View Transition pseudo-elements:

  - `:group` → `::view-transition-group(name)`
  - `:image_pair` → `::view-transition-image-pair(name)`
  - `:old` → `::view-transition-old(name)`
  - `:new` → `::view-transition-new(name)`

  Each key can also have pseudo-class variants:

  - `:old_only_child` → `::view-transition-old(name):only-child`
  - `:new_only_child` → `::view-transition-new(name):only-child`

  The `:only-child` variants apply when an element is being added or removed
  (not replaced), useful for different add/remove vs reorder animations.

  ## With Media Queries

  Properties support conditional values for media queries:

      view_transition "item-*", %{
        old: %{
          animation_name: %{
            :default => :fade_out,
            "@media (prefers-reduced-motion: reduce)" => :none
          },
          animation_duration: "250ms"
        }
      }

  ## Class-based View Transitions

  For more control, use `view_transition_class/2` which generates a class name
  you can apply to elements:

      view_transition_class :card_transition, %{
        old: %{animation_name: :scale_out, animation_duration: "250ms"},
        new: %{animation_name: :scale_in, animation_duration: "250ms"}
      }

      # In templates:
      <div style="view-transition-name: card-1" class={MyApp.Tokens.card_transition()}>
        ...
      </div>

  ## JavaScript Integration

  To enable View Transitions with Phoenix LiveView, add to your `app.js`:

      if (document.startViewTransition) {
        const originalRequestDOMUpdate = liveSocket.requestDOMUpdate.bind(liveSocket)
        liveSocket.requestDOMUpdate = (callback) => {
          document.startViewTransition(() => originalRequestDOMUpdate(callback))
        }
      }

  ## Browser Support

  View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+.
  The animations gracefully degrade in unsupported browsers.
  """

  defmacro __using__(_opts) do
    quote do
      import LiveStyle.ViewTransitions, only: [view_transition_class: 2, view_transition: 2]

      # Register attributes for deferred processing
      Module.register_attribute(__MODULE__, :__live_view_transitions__, accumulate: true)

      # Process view transitions after all other module code
      @before_compile LiveStyle.ViewTransitions
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    view_transitions = Module.get_attribute(env.module, :__live_view_transitions__) || []
    keyframes_list = Module.get_attribute(env.module, :__live_keyframes_map__) || []
    keyframes_map = Map.new(keyframes_list)

    # Process each view transition with the complete keyframes map
    for {name, styles_ast} <- Enum.reverse(view_transitions) do
      {evaluated_styles, _} = Code.eval_quoted(styles_ast, [], env)

      # Validate that all animation_name atom references are defined keyframes
      LiveStyle.ViewTransitions.validate_keyframe_references!(
        evaluated_styles,
        keyframes_map,
        name,
        env
      )

      resolved_styles =
        LiveStyle.ViewTransitions.resolve_keyframes(evaluated_styles, keyframes_map)

      css = LiveStyle.ViewTransitions.generate_name_css(name, resolved_styles)

      LiveStyle.update_manifest(fn manifest ->
        vt_css = manifest[:view_transition_css] || []
        Map.put(manifest, :view_transition_css, [css | vt_css])
      end)
    end

    # Return empty AST
    nil
  end

  @pseudo_element_map %{
    group: "view-transition-group",
    image_pair: "view-transition-image-pair",
    old: "view-transition-old",
    new: "view-transition-new",
    # Variants with :only-child
    group_only_child: {"view-transition-group", "only-child"},
    image_pair_only_child: {"view-transition-image-pair", "only-child"},
    old_only_child: {"view-transition-old", "only-child"},
    new_only_child: {"view-transition-new", "only-child"}
  }

  @doc """
  Creates view transition styles tied to a generated class name.

  This follows StyleX's `viewTransitionClass` pattern. The macro:
  1. Generates a unique class name
  2. Creates CSS rules for the specified pseudo-elements
  3. Defines a function that returns the class name

  ## Example

      view_transition_class :card_transition, %{
        old: %{animation: "\#{scale_out()} 250ms ease-out both"},
        new: %{animation: "\#{scale_in()} 250ms ease-out both"}
      }

      # Use in templates:
      <div class={MyApp.Tokens.card_transition()}>...</div>

  ## Options

  - `:group` - Styles for `::view-transition-group`
  - `:image_pair` - Styles for `::view-transition-image-pair`
  - `:old` - Styles for `::view-transition-old` (outgoing snapshot)
  - `:new` - Styles for `::view-transition-new` (incoming snapshot)
  - `:old_only_child` - Styles for `::view-transition-old:only-child`
  - `:new_only_child` - Styles for `::view-transition-new:only-child`

  ## Note on Keyframe References

  Unlike `view_transition/2`, this macro does not support atom-based keyframe
  references with compile-time validation. Use the function call syntax instead:

      # Use function calls (works):
      view_transition_class :fade, %{
        old: %{animation: "\#{fade_out()} 200ms ease-out both"}
      }

      # Atom references won't be resolved:
      view_transition_class :fade, %{
        old: %{animation_name: :fade_out}  # Won't work!
      }

  For keyframe atom references with validation, use `view_transition/2` instead.
  """
  defmacro view_transition_class(name, styles) when is_atom(name) do
    {evaluated_styles, _} = Code.eval_quoted(styles, [], __CALLER__)

    # Generate a unique class name based on the styles
    styles_string = inspect(evaluated_styles, limit: :infinity)

    hash =
      :crypto.hash(:md5, styles_string)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 7)

    class_name = "vt#{hash}"

    # Generate and register CSS
    css = generate_class_css(class_name, evaluated_styles)

    LiveStyle.update_manifest(fn manifest ->
      vt_css = manifest[:view_transition_css] || []
      Map.put(manifest, :view_transition_css, [css | vt_css])
    end)

    # Define a function that returns the class name
    quote do
      @doc """
      Returns the view transition class name for `#{unquote(name)}`.

      Add this class to elements with a `view-transition-name` style:

          <div style="view-transition-name: my-element" class={\#{unquote(name)}()}>
      """
      def unquote(name)(), do: unquote(class_name)
    end
  end

  @doc """
  Defines view transition styles for elements matching a name pattern.

  Use this for wildcard patterns (e.g., "todo-*") or when you prefer
  name-based transitions over class-based ones.

  ## Example

      defkeyframes :fade_out, %{from: %{opacity: "1"}, to: %{opacity: "0"}}
      defkeyframes :fade_in, %{from: %{opacity: "0"}, to: %{opacity: "1"}}

      view_transition "todo-*", %{
        old: %{
          animation_name: :fade_out,
          animation_duration: "200ms",
          animation_fill_mode: "both"
        },
        new: %{
          animation_name: :fade_in,
          animation_duration: "200ms",
          animation_fill_mode: "both"
        }
      }

  This generates CSS like:

      ::view-transition-old(todo-*) {
        animation-name: k1a2b3c4;
        animation-duration: 200ms;
        animation-fill-mode: both;
      }

  ## Keys

  - `:group` - styles for `::view-transition-group(name)`
  - `:image_pair` - styles for `::view-transition-image-pair(name)`
  - `:old` - styles for `::view-transition-old(name)` (outgoing snapshot)
  - `:new` - styles for `::view-transition-new(name)` (incoming snapshot)
  - `:old_only_child` - styles for `::view-transition-old(name):only-child`
  - `:new_only_child` - styles for `::view-transition-new(name):only-child`

  ## Keyframe References

  Use atoms to reference keyframes defined with `defkeyframes/2`. They are
  validated at compile time - referencing an undefined keyframe raises a
  `CompileError`:

      view_transition "item-*", %{
        old: %{animation_name: :undefined_keyframe}
      }
      # => ** (CompileError) Undefined keyframe reference(s): :undefined_keyframe

  CSS keywords like `:none`, `:inherit`, `:initial`, `:unset` are allowed
  without being defined as keyframes.

  ## Conditional Values

  Use maps for conditional values (e.g., media queries):

      view_transition "item-*", %{
        old: %{
          animation_name: %{
            :default => :fade_out,
            "@media (prefers-reduced-motion: reduce)" => :none
          }
        }
      }
  """
  defmacro view_transition(name, styles) do
    # Store the view transition definition for later processing in __before_compile__
    # This ensures all defkeyframes have been processed first
    quote do
      @__live_view_transitions__ {unquote(name), unquote(Macro.escape(styles))}
    end
  end

  @doc false
  # Generate CSS for class-based view transitions.
  # Public for testing purposes only.
  def generate_class_css(class_name, styles) when is_map(styles) do
    styles
    |> Enum.map(fn {key, declarations} ->
      selector = build_class_selector(class_name, key)
      format_rule(selector, declarations)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc false
  # Generate CSS for name-based view transitions.
  # Public for testing purposes only.
  def generate_name_css(name, styles) when is_map(styles) do
    styles
    |> Enum.map(fn {key, declarations} ->
      selector = build_name_selector(name, key)
      format_rule(selector, declarations)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  # Build selector for class-based transitions: ::view-transition-old(*.vt123)
  defp build_class_selector(class_name, key) when is_atom(key) do
    case lookup_pseudo_element(key) do
      {pseudo_element, pseudo_class} ->
        "::#{pseudo_element}(*.#{class_name}):#{pseudo_class}"

      pseudo_element ->
        "::#{pseudo_element}(*.#{class_name})"
    end
  end

  # Build selector for name-based transitions
  defp build_name_selector(name, key) when is_atom(key) do
    case lookup_pseudo_element(key) do
      {pseudo_element, pseudo_class} ->
        "::#{pseudo_element}(#{name}):#{pseudo_class}"

      pseudo_element ->
        "::#{pseudo_element}(#{name})"
    end
  end

  # Legacy support for string keys like "::view-transition-old"
  defp build_name_selector(name, key) when is_binary(key) do
    build_legacy_selector(name, key)
  end

  defp lookup_pseudo_element(key) do
    case Map.get(@pseudo_element_map, key) do
      nil ->
        raise ArgumentError, """
        Invalid view transition key: #{inspect(key)}

        Valid keys are: :group, :image_pair, :old, :new,
        :group_only_child, :image_pair_only_child, :old_only_child, :new_only_child
        """

      value ->
        value
    end
  end

  defp build_legacy_selector(name, "::" <> rest) do
    case String.split(rest, ":", parts: 2) do
      [pseudo_element] ->
        "::#{pseudo_element}(#{name})"

      [pseudo_element, pseudo_class] ->
        "::#{pseudo_element}(#{name}):#{pseudo_class}"
    end
  end

  defp build_legacy_selector(name, pseudo_element) do
    build_legacy_selector(name, "::" <> pseudo_element)
  end

  defp format_rule(selector, declarations) when is_map(declarations) do
    {default_props, conditional_props} = split_declarations(declarations)

    base_rule =
      if map_size(default_props) > 0 do
        props = format_declarations(default_props)
        "#{selector} {\n  #{props}\n}"
      else
        ""
      end

    conditional_rules =
      Enum.map(conditional_props, fn {condition, props} ->
        formatted_props = format_declarations(props)
        "#{condition} {\n  #{selector} {\n    #{formatted_props}\n  }\n}"
      end)

    [base_rule | conditional_rules]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp split_declarations(declarations) do
    Enum.reduce(declarations, {%{}, %{}}, fn {key, value}, {defaults, conditionals} ->
      case value do
        %{} = conditional_map ->
          split_conditional_value(key, conditional_map, defaults, conditionals)

        _ ->
          {Map.put(defaults, key, value), conditionals}
      end
    end)
  end

  defp split_conditional_value(key, conditional_map, defaults, conditionals) do
    {default_val, conditions} = extract_conditions(conditional_map)

    defaults =
      if default_val, do: Map.put(defaults, key, default_val), else: defaults

    conditionals =
      Enum.reduce(conditions, conditionals, fn {condition, val}, acc ->
        condition_props = Map.get(acc, condition, %{})
        Map.put(acc, condition, Map.put(condition_props, key, val))
      end)

    {defaults, conditionals}
  end

  defp extract_conditions(map) do
    default = Map.get(map, :default) || Map.get(map, "default")

    conditions =
      map
      |> Map.drop([:default, "default"])
      |> Map.to_list()

    {default, conditions}
  end

  defp format_declarations(map) when is_map(map) do
    map
    |> Enum.map_join("\n  ", fn {key, value} ->
      property = key |> to_string() |> String.replace("_", "-")
      "#{property}: #{value};"
    end)
  end

  # Properties that accept keyframe/animation names as values
  @animation_properties ~w(animation_name animationName)a

  @doc false
  # Validates that all animation_name atom references are defined keyframes.
  # Raises CompileError with helpful message if undefined keyframes are found.
  # Public because it's called from __before_compile__ macro.
  def validate_keyframe_references!(styles, keyframes_map, transition_name, env) do
    undefined_refs = collect_undefined_keyframe_refs(styles, keyframes_map, [])

    if undefined_refs != [] do
      defined_keyframes =
        keyframes_map
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map_join(", ", &inspect/1)

      undefined_list =
        undefined_refs
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.map_join(", ", &inspect/1)

      hint =
        if defined_keyframes == "" do
          "No keyframes are defined. Define them with defkeyframes/2 before view_transition/2."
        else
          "Defined keyframes: #{defined_keyframes}"
        end

      raise CompileError,
        file: env.file,
        line: env.line,
        description: """
        Undefined keyframe reference(s) in view_transition #{inspect(transition_name)}: #{undefined_list}

        #{hint}

        Example:
            defkeyframes :fade_out, %{from: %{opacity: "1"}, to: %{opacity: "0"}}

            view_transition "item-*", %{
              old: %{animation_name: :fade_out}
            }
        """
    end

    :ok
  end

  # Collect undefined keyframe references from animation_name properties
  defp collect_undefined_keyframe_refs(styles, keyframes_map, acc) when is_map(styles) do
    Enum.reduce(styles, acc, fn {key, value}, acc ->
      if key in @animation_properties do
        collect_animation_name_refs(value, keyframes_map, acc)
      else
        collect_undefined_keyframe_refs(value, keyframes_map, acc)
      end
    end)
  end

  defp collect_undefined_keyframe_refs(_value, _keyframes_map, acc), do: acc

  # Check animation_name values for undefined keyframe atoms
  defp collect_animation_name_refs(value, keyframes_map, acc) when is_atom(value) do
    # Skip known CSS keywords and pseudo-element keys
    if keyframe_atom?(value) and not Map.has_key?(keyframes_map, value) do
      [value | acc]
    else
      acc
    end
  end

  defp collect_animation_name_refs(value, keyframes_map, acc) when is_map(value) do
    # Conditional map like %{:default => :fade_out, "@media ..." => "none"}
    Enum.reduce(value, acc, fn {_condition, val}, acc ->
      collect_animation_name_refs(val, keyframes_map, acc)
    end)
  end

  defp collect_animation_name_refs(_value, _keyframes_map, acc), do: acc

  # Determine if an atom looks like a keyframe reference vs a CSS keyword
  # CSS keywords like :none, :inherit, :initial, :unset should not be flagged
  @css_keywords ~w(none inherit initial unset revert revert-layer)a
  @pseudo_element_keys ~w(old new group image_pair old_only_child new_only_child
                          group_only_child image_pair_only_child default)a

  defp keyframe_atom?(atom) when atom in @css_keywords, do: false
  defp keyframe_atom?(atom) when atom in @pseudo_element_keys, do: false
  defp keyframe_atom?(_atom), do: true

  @doc false
  # Recursively resolve keyframe atom references in styles.
  # Atoms that match keyframe names get replaced with their hashed names.
  # Public because it's called from __before_compile__ macro and tests.
  def resolve_keyframes(styles, keyframes_map)

  def resolve_keyframes(styles, keyframes_map) when is_map(styles) do
    Map.new(styles, fn {key, value} ->
      {key, resolve_keyframes(value, keyframes_map)}
    end)
  end

  def resolve_keyframes(value, keyframes_map) when is_atom(value) do
    case Map.fetch(keyframes_map, value) do
      {:ok, kf_name} -> kf_name
      :error -> value
    end
  end

  def resolve_keyframes(value, _keyframes_map), do: value
end
