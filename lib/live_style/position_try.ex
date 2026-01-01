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

      defmodule MyApp.Positioning do
        use LiveStyle

        position_try :bottom_fallback,
          top: "anchor(bottom)",
          left: "anchor(center)"
      end

  Or use inline in a style class:

      class :tooltip,
        position: "absolute",
        position_anchor: "--trigger",
        position_try_fallbacks: position_try(
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

  alias LiveStyle.{CSSValue, Hash, Manifest, Property}

  use LiveStyle.Registry,
    entity_name: "Position-try",
    manifest_type: :position_try,
    ref_field: :ident

  @doc false
  @spec allowed_properties() :: MapSet.t()
  def allowed_properties, do: Property.position_try_properties()

  @doc """
  Defines a named position-try rule and stores it in the manifest.
  Called from the position_try/2 macro.
  """
  @spec define(module(), atom(), keyword(), String.t()) :: :ok
  def define(module, name, declarations, ident) do
    key = Manifest.simple_key(module, name)

    entry = %{
      ident: ident,
      declarations: declarations
    }

    store_entry(key, entry)
    :ok
  end

  @doc """
  Defines an anonymous position-try rule and stores it in the manifest.
  Called from the position_try/1 macro with inline declarations.
  """
  @spec define_anonymous(module(), keyword(), String.t()) :: :ok
  def define_anonymous(module, declarations, ident) do
    key = "#{module}:__anon_position_try__:#{ident}"

    entry = %{
      ident: ident,
      declarations: declarations
    }

    store_entry(key, entry)
    :ok
  end

  @doc false
  @spec generate_ident(keyword()) :: String.t()
  def generate_ident(declarations) do
    ident(declarations)
  end

  # Content-based CSS name generation (private)
  defp ident(declarations) do
    css_string =
      declarations
      |> Enum.map(fn {k, v} ->
        css_prop = CSSValue.to_css_property(k)
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
  @spec validate_declarations(keyword()) :: {:ok, keyword()} | {:error, list(String.t())}
  def validate_declarations(declarations) when is_list(declarations) do
    allowed = allowed_properties()

    invalid_props =
      declarations
      |> Keyword.keys()
      |> Enum.map(&CSSValue.to_css_property/1)
      |> Enum.reject(&MapSet.member?(allowed, &1))

    if Enum.empty?(invalid_props) do
      normalized = Enum.map(declarations, fn {k, v} -> {k, normalize_value(v)} end)
      {:ok, normalized}
    else
      {:error, invalid_props}
    end
  end
end
