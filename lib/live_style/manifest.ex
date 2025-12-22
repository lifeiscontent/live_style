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

  alias LiveStyle.Manifest.{Entry, Keys, Ops}

  @spec empty() :: t()
  def empty, do: Ops.empty()

  @spec ensure_keys(term()) :: t()
  def ensure_keys(manifest), do: Ops.ensure_keys(manifest)

  @spec namespaced_key(module(), atom(), atom()) :: String.t()
  def namespaced_key(module, namespace, name), do: Keys.namespaced_key(module, namespace, name)

  @spec simple_key(module(), atom()) :: String.t()
  def simple_key(module, name), do: Keys.simple_key(module, name)

  @spec has_styles?(t()) :: boolean()
  def has_styles?(manifest), do: Ops.has_styles?(manifest)

  # Entry helpers (kept as explicit functions for clarity)
  def put_var(manifest, entry_key, entry), do: Entry.put(manifest, :vars, entry_key, entry)
  def get_var(manifest, entry_key), do: Entry.get(manifest, :vars, entry_key)

  def put_const(manifest, entry_key, entry), do: Entry.put(manifest, :consts, entry_key, entry)
  def get_const(manifest, entry_key), do: Entry.get(manifest, :consts, entry_key)

  def put_keyframes(manifest, entry_key, entry),
    do: Entry.put(manifest, :keyframes, entry_key, entry)

  def get_keyframes(manifest, entry_key), do: Entry.get(manifest, :keyframes, entry_key)

  def put_position_try(manifest, entry_key, entry),
    do: Entry.put(manifest, :position_try, entry_key, entry)

  def get_position_try(manifest, entry_key), do: Entry.get(manifest, :position_try, entry_key)

  def put_view_transition(manifest, entry_key, entry),
    do: Entry.put(manifest, :view_transitions, entry_key, entry)

  def get_view_transition(manifest, entry_key),
    do: Entry.get(manifest, :view_transitions, entry_key)

  def put_class(manifest, entry_key, entry), do: Entry.put(manifest, :classes, entry_key, entry)
  def get_class(manifest, entry_key), do: Entry.get(manifest, :classes, entry_key)

  def put_theme(manifest, entry_key, entry), do: Entry.put(manifest, :themes, entry_key, entry)
  def get_theme(manifest, entry_key), do: Entry.get(manifest, :themes, entry_key)
end
