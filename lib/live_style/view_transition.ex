defmodule LiveStyle.ViewTransition do
  @moduledoc """
  CSS View Transitions API support.

  View transitions enable smooth animations between different DOM states.
  This module handles the generation and storage of view transition class rules
  with content-based hashing (StyleX-compatible).

  ## Browser Support

  View Transitions are supported in Chrome 111+, Edge 111+, and Safari 18+.
  Animations gracefully degrade in unsupported browsers.

  ## Usage

  Define view transitions in a tokens module:

      defmodule MyAppWeb.Transitions do
        use LiveStyle

        keyframes :scale_in,
          from: [opacity: "0", transform: "scale(0.8)"],
          to: [opacity: "1", transform: "scale(1)"]

        keyframes :scale_out,
          from: [opacity: "1", transform: "scale(1)"],
          to: [opacity: "0", transform: "scale(0.8)"]

        view_transition :card,
          old: [
            animation_name: keyframes(:scale_out),
            animation_duration: "200ms"
          ],
          new: [
            animation_name: keyframes(:scale_in),
            animation_duration: "200ms"
          ]
      end

  Apply in templates using `css/2` with the `style` option:

      <div {css([:card_styles], style: [
        view_transition_class: view_transition(:card),
        view_transition_name: "card-\#{@id}"
      ])}>

  Or directly in inline styles:

      <div style={"view-transition-class: \#{view_transition(:card)}; view-transition-name: card-\#{@id}"}>

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

  alias LiveStyle.{CSSValue, Hash, Manifest}

  use LiveStyle.Registry,
    entity_name: "View transition",
    manifest_type: :view_transition,
    ref_field: :ident

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
  @spec validate_keys(keyword()) :: :ok | {:error, list()}
  def validate_keys(styles) when is_list(styles) do
    invalid_keys =
      styles
      |> Keyword.keys()
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

  Returns `{name, entry}` tuple for storage in module attributes.
  """
  @spec define(module(), atom(), keyword()) :: {atom(), keyword()}
  def define(module, name, styles) do
    key = Manifest.key(module, name)
    transition_ident = ident(styles)

    # Keep keyword lists as-is to preserve insertion order (StyleX parity)
    # View transitions preserve the order of pseudo-elements and declarations
    entry = [ident: transition_ident, styles: styles]

    store_entry(key, entry)
    {name, entry}
  end

  # Content-based CSS name generation (private)
  defp ident(styles) do
    css_content = generate_css_string(styles)
    Hash.class_prefix() <> Hash.create_hash(css_content)
  end

  @doc false
  @spec generate_css_string(keyword()) :: String.t()
  def generate_css_string(styles) when is_list(styles) do
    style_list = styles

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

      decl_list = declarations

      # Generate style string in StyleX format: "property:value;"
      # IMPORTANT: Preserve the original property order, do NOT sort
      decl_str =
        Enum.map_join(decl_list, "", fn {prop, value} ->
          css_prop = CSSValue.to_css_property(prop)
          # Apply value normalization (numbers get px, timings normalized, leading zeros removed)
          css_value = CSSValue.to_css(value, css_prop)
          "#{css_prop}:#{css_value};"
        end)

      # StyleX format: "::view-transition-{pseudo}:{styles};"
      # Note the trailing ; after styles - this creates ";;" between pseudos
      "::view-transition-#{css_pseudo}:#{decl_str};"
    end)
  end
end
