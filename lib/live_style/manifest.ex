defmodule LiveStyle.Manifest do
  @moduledoc """
  Manifest structure and operations for LiveStyle.

  The manifest stores all CSS artifacts organized by type:
  - vars: CSS custom properties
  - consts: Compile-time constants (no CSS output)
  - keyframes: @keyframes animations
  - position_try: @position-try rules
  - view_transitions: View transition classes
  - classes: Style classes (atomic CSS)
  - themes: Variable override themes

  Each entry is keyed by a fully-qualified name like "MyApp.Tokens.color.white"
  for namespaced items or "MyApp.Tokens.spin" for non-namespaced items.
  """

  @type var_entry :: %{
          css_name: String.t(),
          value: String.t() | map(),
          type: nil | %{syntax: String.t(), initial: String.t()}
        }

  @type const_entry :: String.t()

  @type keyframes_entry :: %{
          css_name: String.t(),
          frames: map()
        }

  @type position_try_entry :: %{
          css_name: String.t(),
          declarations: map()
        }

  @type view_transition_entry :: %{
          css_name: String.t(),
          styles: map()
        }

  @type class_entry :: %{
          class_string: String.t(),
          atomic_classes: map(),
          declarations: map()
        }

  @type theme_entry :: %{
          css_name: String.t(),
          overrides: map()
        }

  @type t :: %{
          vars: %{String.t() => var_entry()},
          consts: %{String.t() => const_entry()},
          keyframes: %{String.t() => keyframes_entry()},
          position_try: %{String.t() => position_try_entry()},
          view_transitions: %{String.t() => view_transition_entry()},
          classes: %{String.t() => class_entry()},
          themes: %{String.t() => theme_entry()}
        }

  # Manifest sections with their entry types for documentation
  @sections [
    {:var, :vars, "CSS variable"},
    {:const, :consts, "constant"},
    {:keyframes, :keyframes, "keyframes"},
    {:position_try, :position_try, "position-try"},
    {:view_transition, :view_transitions, "view transition"},
    {:class, :classes, "style class"},
    {:theme, :themes, "theme"}
  ]

  @doc """
  Returns an empty manifest with all required keys.
  """
  @spec empty() :: t()
  def empty do
    %{
      vars: %{},
      consts: %{},
      keyframes: %{},
      position_try: %{},
      view_transitions: %{},
      classes: %{},
      themes: %{}
    }
  end

  @doc """
  Ensures manifest has all required keys, adding missing ones.
  """
  @spec ensure_keys(map()) :: t()
  def ensure_keys(manifest) when is_map(manifest) do
    empty()
    |> Map.merge(manifest)
  end

  @doc """
  Generates a manifest key for a namespaced artifact (vars, consts).

  ## Examples

      iex> namespaced_key(MyApp.Tokens, :color, :white)
      "MyApp.Tokens.color.white"
  """
  @spec namespaced_key(module(), atom(), atom()) :: String.t()
  def namespaced_key(module, namespace, name) do
    "#{inspect(module)}.#{namespace}.#{name}"
  end

  @doc """
  Generates a manifest key for a non-namespaced artifact (keyframes, rules, etc).

  ## Examples

      iex> simple_key(MyApp.Tokens, :spin)
      "MyApp.Tokens.spin"
  """
  @spec simple_key(module(), atom()) :: String.t()
  def simple_key(module, name) do
    "#{inspect(module)}.#{name}"
  end

  # Generate put_* and get_* functions for each section
  for {name, key, description} <- @sections do
    put_fn = :"put_#{name}"
    get_fn = :"get_#{name}"

    @doc """
    Registers a #{description} in the manifest.
    """
    def unquote(put_fn)(manifest, entry_key, entry) do
      put_in(manifest, [unquote(key), entry_key], entry)
    end

    @doc """
    Gets a #{description} from the manifest.
    """
    def unquote(get_fn)(manifest, entry_key) do
      get_in(manifest, [unquote(key), entry_key])
    end
  end
end
