defmodule LiveStyle.ViewTransition do
  @moduledoc """
  CSS View Transitions API support.

  View transitions enable smooth animations between different DOM states.
  This module handles the generation and storage of view transition rules
  with content-based hashing (StyleX-compatible).
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest
  alias LiveStyle.Value

  # Valid view transition keys: snake_case atoms or CSS-format strings
  @valid_atom_keys [:group, :image_pair, :old, :new]
  @valid_string_keys ["group", "image-pair", "old", "new"]

  @doc """
  Returns the list of valid view transition atom keys.
  """
  @spec valid_atom_keys() :: list(atom())
  def valid_atom_keys, do: @valid_atom_keys

  @doc """
  Returns the list of valid view transition string keys.
  """
  @spec valid_string_keys() :: list(String.t())
  def valid_string_keys, do: @valid_string_keys

  @doc """
  Validates the keys in a view transition style map.
  Returns :ok or {:error, invalid_keys}.
  """
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
    manifest = LiveStyle.Storage.read()

    # Skip if already exists (from pre-compilation)
    unless Manifest.get_view_transition(manifest, key) do
      styles = normalize_to_map(styles)

      entry = %{
        css_name: css_name,
        styles: styles
      }

      LiveStyle.Storage.update(fn manifest ->
        Manifest.put_view_transition(manifest, key, entry)
      end)
    end

    :ok
  end

  @doc """
  Looks up a view transition by module and name.
  Returns the css_name or raises if not found.
  """
  @spec lookup!(module(), atom()) :: String.t()
  def lookup!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_view_transition(manifest, key) do
      %{css_name: css_name} ->
        css_name

      nil ->
        raise ArgumentError, """
        Unknown view_transition: #{inspect(module)}.#{name}

        Make sure css_view_transition(:#{name}, ...) is defined before it's referenced.
        """
    end
  end

  @doc """
  Gets a view transition name, returning empty string if not found.
  Used for runtime lookups where missing transitions shouldn't raise.
  """
  @spec get_name(module(), atom()) :: String.t()
  def get_name(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_view_transition(manifest, key) do
      %{css_name: css_name} -> css_name
      nil -> ""
    end
  end

  @doc """
  Generates a CSS name hash from the styles.
  """
  @spec generate_css_name(keyword() | map()) :: String.t()
  def generate_css_name(styles) do
    css_content = generate_css_string(styles)
    Hash.view_transition_name(css_content)
  end

  @doc """
  Generates a deterministic CSS string for content-based hashing.

  StyleX format: "::view-transition-group:transition-property:none;;::view-transition-image-pair:border-radius:16px;;..."
  Each pseudo element is formatted as: {pseudo}:{property}:{value};
  And each pseudo element's styles end with an extra ; (so ";;" between pseudos)

  IMPORTANT: StyleX preserves the input order of both pseudo elements and properties.
  We must NOT sort them - use the original order from the keyword list/map.
  """
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

  # Normalize keyword list or map to map
  defp normalize_to_map(value) when is_map(value), do: value
  defp normalize_to_map(value) when is_list(value), do: Map.new(value)
end
