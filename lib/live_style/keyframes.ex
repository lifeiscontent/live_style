defmodule LiveStyle.Keyframes do
  @moduledoc """
  CSS @keyframes animation support for LiveStyle.

  This is an internal module that handles the processing of `css_keyframes/2` definitions.
  You typically don't use this module directly - instead use `LiveStyle.Tokens` with
  the `css_keyframes/2` macro.

  ## Features

  - Content-based hashing for deterministic animation names
  - Frame ordering (from/to/percentage-based)
  - StyleX-compatible CSS generation

  ## Example

  Define keyframes in a tokens module:

      defmodule MyApp.Tokens do
        use LiveStyle.Tokens

        css_keyframes :spin,
          from: [transform: "rotate(0deg)"],
          to: [transform: "rotate(360deg)"]

        css_keyframes :fade_in,
          "0%": [opacity: "0"],
          "100%": [opacity: "1"]
      end

  Reference in a style class:

      css_class :spinner,
        animation: "\#{css_keyframes({MyApp.Tokens, :spin})} 1s linear infinite"
  """

  alias LiveStyle.{Hash, Manifest, Utils, Value}

  @doc """
  Defines a keyframes animation and stores it in the manifest.

  ## Parameters

  - `module` - The module defining the keyframes
  - `name` - The atom name for the keyframes
  - `frames` - A map or keyword list of frame definitions

  ## Returns

  The generated CSS animation name.
  """
  @spec define(module(), atom(), map() | keyword()) :: String.t()
  def define(module, name, frames) do
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    normalized_frames = Utils.normalize_to_map(frames)
    css_name = Hash.keyframes_name(normalized_frames)

    # If already defined, keep it unless the frames changed.
    # In dev/code-reload, keyframes need to update so the compiled CSS matches source.
    case Manifest.get_keyframes(manifest, key) do
      %{css_name: ^css_name, frames: ^normalized_frames} ->
        css_name

      _existing ->
        # Generate the StyleX-compatible metadata
        ltr = generate_css(css_name, normalized_frames)

        entry = %{
          css_name: css_name,
          frames: normalized_frames,
          ltr: ltr,
          rtl: nil,
          priority: 0
        }

        LiveStyle.Storage.update(fn manifest ->
          Manifest.put_keyframes(manifest, key, entry)
        end)

        css_name
    end
  end

  @doc """
  Looks up a keyframes animation by module and name.

  Returns the CSS animation name or raises if not found.
  """
  @spec lookup!(module(), atom()) :: String.t()
  def lookup!(module, name) do
    %{css_name: css_name} = LiveStyle.Manifest.Access.keyframes!(module, name)
    css_name
  end

  @doc """
  Generates the CSS string for a keyframes animation.

  Format: `@keyframes name{from{prop:value;}to{prop:value;}}`
  """
  @spec generate_css(String.t(), map()) :: String.t()
  def generate_css(css_name, frames) do
    sorted_frames =
      frames
      |> Enum.sort_by(fn {frame_key, _} -> frame_sort_order(frame_key) end)

    frame_css =
      Enum.map_join(sorted_frames, "", fn {frame_key, props} ->
        frame_name = normalize_frame_key(frame_key)
        props_css = generate_frame_props_css(props)
        "#{frame_name}{#{props_css}}"
      end)

    "@keyframes #{css_name}{#{frame_css}}"
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

  # Normalize frame key to string
  defp normalize_frame_key(:from), do: "from"
  defp normalize_frame_key(:to), do: "to"
  defp normalize_frame_key(key) when is_binary(key), do: key
  defp normalize_frame_key(key) when is_atom(key), do: Atom.to_string(key)

  # Generate CSS for a single frame's properties
  defp generate_frame_props_css(props) when is_map(props) or is_list(props) do
    props
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {prop, value} ->
      css_prop = Value.to_css_property(prop)
      css_value = Value.to_css(value, css_prop)
      "#{css_prop}:#{css_value};"
    end)
  end
end
