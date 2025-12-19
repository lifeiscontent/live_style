defmodule LiveStyle.Hash do
  @moduledoc """
  Hash generation functions for LiveStyle.

  Uses MurmurHash2 algorithm (matching StyleX) for class name generation.
  Output is base36 encoded for compact class names.

  The class name prefix can be configured via:

      config :live_style, class_name_prefix: "x"

  Default is "x" (matching StyleX).
  """

  alias LiveStyle.Hash.Murmur
  alias LiveStyle.Pseudo.Sort, as: PseudoSort

  @seed 1

  # Get the class name prefix from config (default "x")
  defp class_prefix do
    LiveStyle.Config.class_name_prefix()
  end

  @doc """
  Generates a CSS class name from property, value, pseudos, and at-rules.

  This matches StyleX's convertStyleToClassName hash generation:
  - Input: dashedKey + valueAsString + modifierHashString
  - Hash: MurmurHash2 with seed 1
  - Output: classNamePrefix + base36(hash)

  ## Examples

      iex> LiveStyle.Hash.class_name("display", "flex", [], [])
      "xabcdef"

      iex> LiveStyle.Hash.class_name("color", "red", [":hover"], [])
      "x123456"
  """
  @spec class_name(String.t(), String.t(), list(String.t()), list(String.t())) :: String.t()
  def class_name(property, value, pseudos, at_rules) do
    # Sort pseudos and at-rules (matching StyleX's sortPseudos and sortAtRules)
    sorted_pseudos = PseudoSort.sort(pseudos)
    sorted_at_rules = sort_at_rules(at_rules)

    pseudo_hash_string = Enum.join(sorted_pseudos, "")
    at_rule_hash_string = Enum.join(sorted_at_rules, "")

    # StyleX uses 'null' when no modifiers to keep existing hashes stable
    combined = pseudo_hash_string <> at_rule_hash_string
    modifier_hash_string = if combined == "", do: "null", else: combined

    # StyleX prefixes with '<>' for hash stability
    string_to_hash = "<>" <> property <> value <> modifier_hash_string
    hash = create_hash(string_to_hash)

    # Debug mode: include property name in class for easier debugging
    # e.g., "background-color-x1a2b3c4" instead of "x1a2b3c4"
    # Uses kebab-case (CSS standard) instead of camelCase (JS convention)
    if LiveStyle.Config.debug_class_names?() do
      "#{property}-#{class_prefix()}#{hash}"
    else
      class_prefix() <> hash
    end
  end

  @doc """
  Generates a CSS variable name.

  ## Examples

      iex> LiveStyle.Hash.var_name(MyModule, :color, :primary)
      "--xabcdef"
  """
  @spec var_name(module(), atom(), atom()) :: String.t()
  def var_name(module, namespace, name) do
    input = "var:#{inspect(module)}.#{namespace}.#{name}"
    "--v" <> create_hash(input)
  end

  @doc """
  Generates a keyframes animation name.
  Identical keyframes produce the same name (deduplication).

  Uses the same hash format as StyleX:
  - Input: "<>" + "frame{prop:value;}frame{prop:value;}"
  - Where frames are sorted and properties within each frame are sorted

  ## Examples

      iex> LiveStyle.Hash.keyframes_name(%{from: %{opacity: 0}, to: %{opacity: 1}})
      "xabcdef-B"
  """
  @spec keyframes_name(map()) :: String.t()
  def keyframes_name(frames) when is_map(frames) do
    # Build the keyframes string in StyleX format: frame{prop:value;}frame{prop:value;}
    keyframes_string = construct_keyframes_string(frames)
    # StyleX prefixes with '<>' for hash stability (see stylex-keyframes.js line 66)
    class_prefix() <> create_hash("<>" <> keyframes_string) <> "-B"
  end

  # Construct keyframes string in StyleX format: from{color:red;}to{color:blue;}
  defp construct_keyframes_string(frames) do
    frames
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map_join("", fn {frame_key, declarations} ->
      # StyleX validation: keyframe values must be objects (keyword lists or maps)
      validate_keyframe_declarations!(frame_key, declarations)

      decls_string =
        declarations
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)
        |> Enum.map_join("", fn {prop, value} ->
          # Convert property to kebab-case if needed (e.g., :background_color -> "background-color")
          prop_str = LiveStyle.Value.to_css_property(prop)
          "#{prop_str}:#{value};"
        end)

      "#{frame_key}{#{decls_string}}"
    end)
  end

  # StyleX validation: keyframe values must be objects (keyword lists or maps)
  # Matches validation-stylex-keyframes-test.js: messages.NON_OBJECT_KEYFRAME
  defp validate_keyframe_declarations!(frame_key, declarations) do
    unless is_list(declarations) or is_map(declarations) do
      raise ArgumentError,
            "Keyframe value must be a keyword list or map, got: #{inspect(declarations)} for frame: #{frame_key}"
    end
  end

  @doc """
  Generates a theme class name from module, namespace, and theme name.

  ## Examples

      iex> LiveStyle.Hash.theme_name(MyModule, :color, :dark)
      "t123456"
  """
  @spec theme_name(module(), atom(), atom()) :: String.t()
  def theme_name(module, namespace, theme_name) do
    input = "theme:#{inspect(module)}.#{namespace}.#{theme_name}"
    "t" <> create_hash(input)
  end

  @doc """
  Generates a theme class name from content string.
  """
  @spec theme_name(String.t()) :: String.t()
  def theme_name(content) when is_binary(content) do
    "t" <> create_hash(content)
  end

  @doc """
  Generates a marker class name.
  """
  @spec marker_name(atom()) :: String.t()
  def marker_name(name) do
    # StyleX format: just x{hash} without any prefix
    class_prefix() <> create_hash("marker:#{name}")
  end

  @doc """
  Generates a position-try dashed-ident from CSS declarations.
  """
  @spec position_try_name(String.t()) :: String.t()
  def position_try_name(declarations_css) do
    "--" <> class_prefix() <> create_hash(declarations_css)
  end

  @doc """
  Generates a position-try dashed-ident from module and name.
  """
  @spec position_try_name(module(), atom()) :: String.t()
  def position_try_name(module, name) do
    input = "position_try:#{inspect(module)}.#{name}"
    "--pt-" <> class_prefix() <> create_hash(input)
  end

  @doc """
  Generates a view-transition name based on content (StyleX-compatible).
  """
  @spec view_transition_name(String.t()) :: String.t()
  def view_transition_name(css_content) do
    class_prefix() <> create_hash(css_content)
  end

  @doc """
  Generates an atomic class name for a CSS property/value pair.

  ## Parameters

    * `property` - CSS property name (e.g., "color")
    * `value` - CSS value (e.g., "red")
    * `pseudo_element` - Pseudo-element selector (e.g., "::before") or nil
    * `selector_suffix` - Pseudo-class selector (e.g., ":hover") or nil
    * `at_rule` - At-rule wrapper (e.g., "@media (min-width: 800px)") or nil

  ## Examples

      iex> LiveStyle.Hash.atomic_class("color", "red", nil, nil, nil)
      "x1abc234"

      iex> LiveStyle.Hash.atomic_class("color", "blue", nil, ":hover", nil)
      "x2def567"
  """
  @spec atomic_class(
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) :: String.t()
  def atomic_class(property, value, pseudo_element, selector_suffix, at_rule) do
    # Split combined pseudo strings into individual pseudos
    # e.g., ":hover:active" -> [":hover", ":active"]
    pseudos =
      [pseudo_element, selector_suffix]
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.flat_map(&PseudoSort.split/1)

    at_rules =
      if at_rule && at_rule != "",
        do: [at_rule],
        else: []

    class_name(property, value, pseudos, at_rules)
  end

  @doc """
  Generates a dynamic CSS variable name for runtime-set values.
  """
  @spec dynamic_var(module(), atom(), atom(), non_neg_integer()) :: String.t()
  def dynamic_var(module, style_name, prop, idx) do
    input = "#{inspect(module)}:#{style_name}:#{prop}:#{idx}"
    "--x" <> create_hash(input) <> "-#{idx}"
  end

  @doc """
  Creates a hash string using MurmurHash2, encoded in base36.
  This matches StyleX's hash function.
  """
  @spec create_hash(String.t()) :: String.t()
  def create_hash(str) do
    Murmur.hash(str, @seed)
    |> Integer.to_string(36)
    |> String.downcase()
  end

  # Sorts at-rules alphabetically (matches StyleX's sortAtRules)
  defp sort_at_rules(at_rules), do: Enum.sort(at_rules)
end
