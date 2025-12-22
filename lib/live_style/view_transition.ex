defmodule LiveStyle.ViewTransition do
  @moduledoc """
  CSS View Transitions API support.

  View transitions enable smooth animations between different DOM states.
  This module handles the generation and storage of view transition rules
  with content-based hashing (StyleX-compatible).

  ## Browser Support

  View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+.
  Animations gracefully degrade in unsupported browsers.

  ## Usage

  Define view transitions in a tokens module:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_keyframes :scale_in,
          from: [opacity: "0", transform: "scale(0.8)"],
          to: [opacity: "1", transform: "scale(1)"]

        css_keyframes :scale_out,
          from: [opacity: "1", transform: "scale(1)"],
          to: [opacity: "0", transform: "scale(0.8)"]

        css_view_transition :card,
          old: [
            animation_name: css_keyframes(:scale_out),
            animation_duration: "200ms"
          ],
          new: [
            animation_name: css_keyframes(:scale_in),
            animation_duration: "200ms"
          ]
      end

  Apply in templates using `css/2` with the `style` option:

      <div {css([:card_styles], style: [
        view_transition_class: css_view_transition(:card),
        view_transition_name: "card-\#{@id}"
      ])}>

  Or directly in inline styles:

      <div style={"view-transition-class: \#{css_view_transition(:card)}; view-transition-name: card-\#{@id}"}>

  ## Available Pseudo-element Keys

  - `:old` - `::view-transition-old(name)`
  - `:new` - `::view-transition-new(name)`
  - `:group` - `::view-transition-group(name)`
  - `:image_pair` - `::view-transition-image-pair(name)`

  ## Phoenix LiveView Integration

  For Phoenix LiveView 1.1.18+, enable view transitions with `onDocumentPatch`:

      const liveSocket = new LiveSocket("/live", Socket, {
        dom: {
          onDocumentPatch(proceed) {
            if (document.startViewTransition) {
              document.startViewTransition(proceed)
            } else {
              proceed()
            }
          }
        }
      })
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest
  alias LiveStyle.Utils
  alias LiveStyle.Value

  # Valid view transition keys: snake_case atoms or CSS-format strings
  @valid_atom_keys [:group, :image_pair, :old, :new]
  @valid_string_keys ["group", "image-pair", "old", "new"]

  @doc false
  @spec valid_atom_keys() :: list(atom())
  def valid_atom_keys, do: @valid_atom_keys

  @doc false
  @spec valid_string_keys() :: list(String.t())
  def valid_string_keys, do: @valid_string_keys

  @doc false
  @spec validate_keys(map()) :: :ok | {:error, list()}
  def validate_keys(style_map) do
    invalid_keys =
      style_map
      |> Map.keys()
      |> Enum.reject(fn key ->
        key in @valid_atom_keys or key in @valid_string_keys
      end)

    if invalid_keys == [] do
      :ok
    else
      {:error, invalid_keys}
    end
  end

  @doc """
  Defines a named view transition and stores it in the manifest.
  """
  @spec define(module(), atom(), map() | keyword(), String.t()) :: :ok
  def define(module, name, styles, css_name) do
    key = Manifest.simple_key(module, name)
    styles = Utils.normalize_to_map(styles)

    entry = %{
      css_name: css_name,
      styles: styles
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_view_transition(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_view_transition(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Looks up a view transition by module and name.
  Returns the css_name or raises if not found.
  """
  @spec lookup!(module(), atom()) :: String.t()
  def lookup!(module, name) do
    %{css_name: css_name} = LiveStyle.Manifest.Access.view_transition!(module, name)
    css_name
  end

  @doc false
  @spec generate_css_name(keyword() | map()) :: String.t()
  def generate_css_name(styles) do
    css_content = generate_css_string(styles)
    Hash.view_transition_name(css_content)
  end

  @doc false
  @spec generate_css_string(keyword() | map()) :: String.t()
  def generate_css_string(styles) do
    # Convert to list preserving order (keyword list stays as-is, map gets converted)
    style_list = if is_list(styles), do: styles, else: Enum.to_list(styles)

    Enum.map_join(style_list, "", fn {pseudo_key, declarations} ->
      # Normalize pseudo key to CSS format (image_pair -> image-pair)
      css_pseudo =
        pseudo_key
        |> to_string()
        |> String.replace("_", "-")
        |> then(fn
          <<":", rest::binary>> -> rest
          s -> s
        end)

      # Convert declarations to list preserving order
      decl_list = if is_list(declarations), do: declarations, else: Enum.to_list(declarations)

      # Generate style string in StyleX format: "property:value;"
      # IMPORTANT: Preserve the original property order, do NOT sort
      decl_str =
        Enum.map_join(decl_list, "", fn {prop, value} ->
          css_prop = Value.to_css_property(prop)
          # Apply value normalization (numbers get px, timings normalized, leading zeros removed)
          css_value = Value.to_css(value, css_prop)
          "#{css_prop}:#{css_value};"
        end)

      # StyleX format: "::view-transition-{pseudo}:{styles};"
      # Note the trailing ; after styles - this creates ";;" between pseudos
      "::view-transition-#{css_pseudo}:#{decl_str};"
    end)
  end
end
