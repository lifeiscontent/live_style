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

  alias LiveStyle.{Hash, Manifest, Value}

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

    # Return existing if already defined (from pre-compilation)
    case Manifest.get_keyframes(manifest, key) do
      %{css_name: css_name} ->
        css_name

      nil ->
        normalized_frames = normalize_frames(frames)
        css_name = Hash.keyframes_name(normalized_frames)

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
    key = Manifest.simple_key(module, name)
    manifest = LiveStyle.Storage.read()

    case Manifest.get_keyframes(manifest, key) do
      %{css_name: css_name} ->
        css_name

      nil ->
        raise ArgumentError, """
        Unknown keyframes: #{name}

        Make sure css_keyframes(:#{name}, ...) is defined before it's referenced.
        If referencing from another module, ensure that module is compiled first.
        """
    end
  end

  @doc """
  Generates the CSS string for a keyframes animation.

  Format: `@keyframes name{from{prop:value;}to{prop:value;}}`
  """
  @spec generate_css(String.t(), map()) :: String.t()
  def generate_css(css_name, frames) do
    sorted_frames =
      frames
      |> Enum.sort_by(fn {frame_key, _} -> frame_sort_key(frame_key) end)

    frame_css =
      Enum.map_join(sorted_frames, "", fn {frame_key, props} ->
        frame_name = normalize_frame_key(frame_key)
        props_css = generate_frame_props_css(props)
        "#{frame_name}{#{props_css}}"
      end)

    "@keyframes #{css_name}{#{frame_css}}"
  end

  defp normalize_frames(frames) when is_list(frames), do: Map.new(frames)
  defp normalize_frames(frames) when is_map(frames), do: frames

  # Sort key for frame ordering (0 = first, 100 = last)
  defp frame_sort_key(:from), do: 0
  defp frame_sort_key("from"), do: 0
  defp frame_sort_key("0%"), do: 0
  defp frame_sort_key(:to), do: 100
  defp frame_sort_key("to"), do: 100
  defp frame_sort_key("100%"), do: 100

  defp frame_sort_key(key) when is_binary(key) do
    # Parse percentage like "50%" -> 50
    case Integer.parse(String.trim_trailing(key, "%")) do
      {num, ""} ->
        num

      _ ->
        raise ArgumentError,
              "Invalid keyframe key: #{inspect(key)}. Expected 'from', 'to', or a percentage like '50%'"
    end
  end

  defp frame_sort_key(key) do
    raise ArgumentError,
          "Invalid keyframe key: #{inspect(key)}. Expected atom (:from, :to) or string ('50%')"
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
