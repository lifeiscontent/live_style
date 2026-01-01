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

  # Increment this when the manifest format changes to trigger regeneration.
  # This ensures stale manifests from previous versions are cleared.
  @current_version 2

  @type var_entry :: %{
          ident: String.t(),
          value: String.t() | map(),
          type: nil | %{syntax: String.t(), initial: String.t()}
        }

  @type const_entry :: String.t()

  @type keyframes_entry :: %{
          ident: String.t(),
          frames: map()
        }

  @type position_try_entry :: %{
          ident: String.t(),
          declarations: map()
        }

  @type view_transition_entry :: %{
          ident: String.t(),
          styles: map()
        }

  @type class_entry :: %{
          class_string: String.t(),
          atomic_classes: map(),
          declarations: map()
        }

  @type theme_entry :: %{
          ident: String.t(),
          overrides: map()
        }

  @type t :: %{
          version: pos_integer(),
          vars: %{String.t() => var_entry()},
          consts: %{String.t() => const_entry()},
          keyframes: %{String.t() => keyframes_entry()},
          position_try: %{String.t() => position_try_entry()},
          view_transitions: %{String.t() => view_transition_entry()},
          classes: %{String.t() => class_entry()},
          themes: %{String.t() => theme_entry()}
        }

  @doc """
  Returns the current manifest version.
  """
  @spec current_version() :: pos_integer()
  def current_version, do: @current_version

  @spec empty() :: t()
  def empty do
    %{
      version: @current_version,
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
  Checks if the manifest version is current.
  """
  @spec current?(t()) :: boolean()
  def current?(%{version: version}), do: version == @current_version
  def current?(_), do: false

  @spec ensure_keys(term()) :: t()
  def ensure_keys(manifest) when is_map(manifest) do
    # If manifest version doesn't match current, discard old data and return fresh
    # This handles format changes that would otherwise cause runtime errors
    if current?(manifest) do
      struct_merge(empty(), manifest)
    else
      empty()
    end
  end

  def ensure_keys(_manifest), do: empty()

  @spec namespaced_key(module(), atom(), atom()) :: String.t()
  def namespaced_key(module, namespace, name), do: "#{inspect(module)}.#{namespace}.#{name}"

  @spec simple_key(module(), atom()) :: String.t()
  def simple_key(module, name), do: "#{inspect(module)}.#{name}"

  @spec has_styles?(t()) :: boolean()
  def has_styles?(manifest) do
    has_entries?(manifest, :vars) or
      has_entries?(manifest, :keyframes) or
      has_entries?(manifest, :classes) or
      has_entries?(manifest, :position_try) or
      has_entries?(manifest, :view_transitions) or
      has_entries?(manifest, :themes)
  end

  defp has_entries?(manifest, key), do: map_size(manifest[key] || %{}) > 0

  defp struct_merge(base, updates) when is_map(base) and is_map(updates) do
    Enum.reduce(updates, base, fn {k, v}, acc ->
      if is_map_key(acc, k), do: %{acc | k => v}, else: acc
    end)
  end

  # Entry helpers
  def put_var(manifest, key, entry), do: put_in(manifest, [:vars, key], entry)
  def get_var(manifest, key), do: get_in(manifest, [:vars, key])

  def put_const(manifest, key, entry), do: put_in(manifest, [:consts, key], entry)
  def get_const(manifest, key), do: get_in(manifest, [:consts, key])

  def put_keyframes(manifest, key, entry), do: put_in(manifest, [:keyframes, key], entry)
  def get_keyframes(manifest, key), do: get_in(manifest, [:keyframes, key])

  def put_position_try(manifest, key, entry), do: put_in(manifest, [:position_try, key], entry)
  def get_position_try(manifest, key), do: get_in(manifest, [:position_try, key])

  def put_view_transition(manifest, key, entry),
    do: put_in(manifest, [:view_transitions, key], entry)

  def get_view_transition(manifest, key), do: get_in(manifest, [:view_transitions, key])

  def put_class(manifest, key, entry), do: put_in(manifest, [:classes, key], entry)
  def get_class(manifest, key), do: get_in(manifest, [:classes, key])

  def put_theme(manifest, key, entry), do: put_in(manifest, [:themes, key], entry)
  def get_theme(manifest, key), do: get_in(manifest, [:themes, key])
end
