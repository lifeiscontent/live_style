defmodule LiveStyle.Keyframes do
  @moduledoc """
  CSS @keyframes animation support for LiveStyle.

  This is an internal module that handles the processing of `keyframes/2` definitions.
  You typically don't use this module directly - instead use `LiveStyle` with
  the `keyframes/2` macro.

  ## Features

  - Content-based hashing for deterministic animation names
  - Frame ordering (from/to/percentage-based)
  - StyleX-compatible CSS generation

  ## Example

  Define keyframes in a tokens module:

      defmodule MyAppWeb.Animations do
        use LiveStyle

        keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]

        keyframes :fade_in,
          "0%": [opacity: "0"],
          "100%": [opacity: "1"]
      end

  Reference in a style class:

      class :spinner,
        animation: "\#{keyframes({MyAppWeb.Animations, :spin})} 1s linear infinite"
  """

  alias LiveStyle.{CSSValue, Hash, Manifest}

  use LiveStyle.Registry,
    entity_name: "Keyframes",
    manifest_type: :keyframes,
    ref_field: :ident

  # Content-based CSS name generation (private)
  # Identical keyframes produce the same name for deduplication
  defp ident(frames) when is_list(frames) do
    keyframes_string = serialize_frames(frames)
    # StyleX prefixes with '<>' for hash stability
    Hash.class_prefix() <> Hash.create_hash("<>" <> keyframes_string) <> "-B"
  end

  # Serialize frames in StyleX format: from{color:red;}to{color:blue;}
  # Frames are sorted by key for consistent hashing, but declarations within
  # frames are also sorted for hash consistency.
  defp serialize_frames(frames) do
    frames
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {frame_key, declarations} ->
      validate_frame_declarations!(frame_key, declarations)

      decls_string =
        declarations
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)
        |> Enum.map_join("", fn {prop, value} ->
          prop_str = CSSValue.to_css_property(prop)
          "#{prop_str}:#{value};"
        end)

      "#{frame_key}{#{decls_string}}"
    end)
  end

  defp validate_frame_declarations!(frame_key, declarations) do
    unless is_list(declarations) do
      raise ArgumentError,
            "Keyframe value must be a keyword list, got: #{inspect(declarations)} for frame: #{frame_key}"
    end
  end

  @doc """
  Defines a keyframes animation and stores it in the manifest.

  ## Parameters

  - `module` - The module defining the keyframes
  - `name` - The atom name for the keyframes
  - `frames` - A map or keyword list of frame definitions

  ## Returns

  `{name, entry}` tuple for storage in module attributes.
  """
  @spec define(module(), atom(), keyword()) :: {atom(), keyword()}
  def define(module, name, frames) when is_list(frames) do
    key = Manifest.key(module, name)
    keyframes_ident = ident(frames)
    entry = [ident: keyframes_ident, frames: frames]

    # Store in manifest for CSS generation
    LiveStyle.Storage.update(fn manifest ->
      Manifest.put_keyframes(manifest, key, entry)
    end)

    {name, entry}
  end

  @doc false
  # Returns the sort order for a keyframe key (0 = from, 100 = to).
  # Used by both Keyframes and CSS.Keyframes for consistent ordering.
  @spec frame_sort_order(atom() | String.t()) :: integer()
  def frame_sort_order(key) when is_atom(key) do
    # Normalize atom keys to strings for unified handling
    frame_sort_order(Atom.to_string(key))
  end

  def frame_sort_order("from"), do: 0
  def frame_sort_order("0%"), do: 0
  def frame_sort_order("to"), do: 100
  def frame_sort_order("100%"), do: 100

  def frame_sort_order(key) when is_binary(key) do
    # Handle comma-separated keys like "0%, 100%" by taking the first value
    first_key =
      key
      |> String.split(",")
      |> hd()
      |> String.trim()

    case Integer.parse(String.trim_trailing(first_key, "%")) do
      {num, ""} -> num
      {num, "%"} -> num
      _ -> raise ArgumentError, invalid_frame_key_message(key)
    end
  end

  defp invalid_frame_key_message(key) do
    "Invalid keyframe key: #{inspect(key)}. Expected 'from', 'to', or a percentage like '50%'"
  end
end
