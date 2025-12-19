defmodule LiveStyle.PositionTry do
  @moduledoc """
  CSS Anchor Positioning `@position-try` rule support.

  This module handles `@position-try` at-rules for CSS Anchor Positioning,
  which provides fallback positioning for anchored elements.

  ## Browser Support

  CSS Anchor Positioning is available in Chromium 125+ (June 2024).
  Firefox and Safari do not yet support this feature.

  ## Usage

  Define position-try rules in a tokens module or inline:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_position_try :bottom_fallback,
          top: "anchor(bottom)",
          left: "anchor(center)"
      end

  Or use inline in a style class:

      css_class :tooltip,
        position: "absolute",
        position_anchor: "--trigger",
        position_try_fallbacks: css_position_try(
          bottom: "anchor(top)",
          left: "anchor(center)"
        )

  ## Allowed Properties

  Only positioning-related properties are allowed in `@position-try` rules:

  - **Position anchor**: `position_anchor`, `position_area`
  - **Inset**: `top`, `right`, `bottom`, `left`, `inset`, `inset_block`, `inset_inline`
  - **Margin**: `margin`, `margin_top`, `margin_inline_start`, etc.
  - **Size**: `width`, `height`, `min_width`, `max_height`, `block_size`, `inline_size`
  - **Self-alignment**: `align_self`, `justify_self`, `place_self`

  ## RTL Handling

  Position-try rules use CSS properties that are either:
  - Physical (top, left, width, height) - no RTL transformation needed
  - Logical (inset-inline-start, margin-block) - browser handles RTL automatically
  """

  alias LiveStyle.Hash
  alias LiveStyle.Manifest
  alias LiveStyle.Property
  alias LiveStyle.Value

  @doc false
  @spec allowed_properties() :: MapSet.t()
  def allowed_properties, do: Property.position_try_properties()

  @doc """
  Defines a named position-try rule and stores it in the manifest.
  Called from the css_position_try/2 macro.
  """
  @spec define(module(), atom(), map(), String.t()) :: :ok
  def define(module, name, declarations, css_name) do
    key = Manifest.simple_key(module, name)

    entry = %{
      css_name: css_name,
      declarations: declarations
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_position_try(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_position_try(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Defines an anonymous position-try rule and stores it in the manifest.
  Called from the css_position_try/1 macro with inline declarations.
  """
  @spec define_anonymous(module(), map(), String.t()) :: :ok
  def define_anonymous(module, declarations, css_name) do
    key = "#{module}:__anon_position_try__:#{css_name}"

    entry = %{
      css_name: css_name,
      declarations: declarations
    }

    # Only update if the entry has changed (or doesn't exist)
    LiveStyle.Storage.update(fn manifest ->
      case Manifest.get_position_try(manifest, key) do
        ^entry -> manifest
        _ -> Manifest.put_position_try(manifest, key, entry)
      end
    end)

    :ok
  end

  @doc """
  Looks up a position-try by module and name.
  Returns the css_name or raises if not found.
  """
  @spec lookup!(module(), atom()) :: String.t()
  def lookup!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_position_try(manifest, key) do
      %{css_name: css_name} ->
        css_name

      nil ->
        raise ArgumentError, """
        Unknown position_try: #{inspect(module)}.#{name}

        Make sure css_position_try(:#{name}, ...) is defined before it's referenced.
        """
    end
  end

  @doc false
  @spec generate_css_name(map()) :: String.t()
  def generate_css_name(declarations) do
    css_string =
      declarations
      |> Enum.map(fn {k, v} ->
        css_prop = Value.to_css_property(k)
        {css_prop, v}
      end)
      |> Enum.sort_by(fn {k, _} -> k end)
      # StyleX LTR format: "key:key;key:value;" for each property
      |> Enum.map_join("", fn {k, v} -> "#{k}:#{k};#{k}:#{v};" end)

    "--x" <> Hash.create_hash(css_string)
  end

  @doc false
  @spec normalize_value(term()) :: String.t()
  def normalize_value(value) when is_integer(value), do: "#{value}px"
  def normalize_value(value) when is_float(value), do: "#{value}px"
  def normalize_value(value) when is_binary(value), do: value
  def normalize_value(value) when is_atom(value), do: Atom.to_string(value)

  @doc false
  @spec validate_declarations(map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate_declarations(declarations) do
    allowed = allowed_properties()

    invalid_props =
      declarations
      |> Map.keys()
      |> Enum.map(&Value.to_css_property/1)
      |> Enum.reject(&MapSet.member?(allowed, &1))

    if Enum.empty?(invalid_props) do
      normalized = Map.new(declarations, fn {k, v} -> {k, normalize_value(v)} end)
      {:ok, normalized}
    else
      {:error, invalid_props}
    end
  end
end
