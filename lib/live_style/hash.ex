defmodule LiveStyle.Hash do
  @moduledoc """
  Hash generation functions for LiveStyle.

  Uses MurmurHash2 algorithm (matching StyleX) for class name generation.
  Output is base36 encoded for compact class names.

  The class name prefix can be configured via:

      config :live_style, class_name_prefix: "x"

  Default is "x" (matching StyleX).
  """

  import Bitwise

  alias LiveStyle.Pseudo

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
    sorted_pseudos = sort_pseudos(pseudos)
    sorted_at_rules = sort_at_rules(at_rules)

    pseudo_hash_string = Enum.join(sorted_pseudos, "")
    at_rule_hash_string = Enum.join(sorted_at_rules, "")

    # StyleX uses 'null' when no modifiers to keep existing hashes stable
    modifier_hash_string =
      case pseudo_hash_string <> at_rule_hash_string do
        "" -> "null"
        str -> str
      end

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
      |> Enum.flat_map(&split_pseudos/1)

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
    murmurhash2_32(str, @seed)
    |> Integer.to_string(36)
    |> String.downcase()
  end

  @doc """
  MurmurHash2 32-bit implementation.

  Port of the JavaScript implementation used by StyleX.
  """
  @spec murmurhash2_32(String.t(), non_neg_integer()) :: non_neg_integer()
  def murmurhash2_32(str, seed \\ 0) do
    bytes = :binary.bin_to_list(str)
    len = length(bytes)

    # Initialize hash
    h = bxor(seed, len) |> band(0xFFFFFFFF)

    # Process 4-byte chunks
    {h, remaining} = process_chunks(bytes, h)

    # Process remaining bytes
    h = process_tail(remaining, h)

    # Final mixing
    h = js_xor(h, js_unsigned_shift(h, 13))
    h = js_multiply(h, 0x5BD1E995) |> band(0xFFFFFFFF)
    h = js_xor(h, js_unsigned_shift(h, 15))

    h
  end

  # Process 4-byte chunks
  defp process_chunks(bytes, h) when length(bytes) >= 4 do
    [b0, b1, b2, b3 | rest] = bytes

    k =
      band(b0, 0xFF)
      |> bor(bsl(band(b1, 0xFF), 8))
      |> bor(bsl(band(b2, 0xFF), 16))
      |> bor(bsl(band(b3, 0xFF), 24))

    # JS-style multiplication (can produce values > 32-bit)
    k = js_multiply(k, 0x5BD1E995)
    # XOR: JS >>> treats value as 32-bit unsigned first
    k = js_xor(k, js_unsigned_shift(k, 24))
    k = js_multiply(k, 0x5BD1E995)

    h = js_multiply(h, 0x5BD1E995)
    h = js_xor(h, k)

    process_chunks(rest, h)
  end

  defp process_chunks(bytes, h), do: {h, bytes}

  # Process remaining bytes (tail)
  defp process_tail([], h), do: h

  defp process_tail([b0], h) do
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  defp process_tail([b0, b1], h) do
    h = js_xor(h, bsl(band(b1, 0xFF), 8))
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  defp process_tail([b0, b1, b2], h) do
    h = js_xor(h, bsl(band(b2, 0xFF), 16))
    h = js_xor(h, bsl(band(b1, 0xFF), 8))
    h = js_xor(h, band(b0, 0xFF))
    js_multiply(h, 0x5BD1E995)
  end

  # JavaScript-style unsigned right shift (>>>)
  # JS >>> treats the value as 32-bit unsigned BEFORE shifting
  defp js_unsigned_shift(n, bits) do
    band(n, 0xFFFFFFFF) >>> bits
  end

  # JavaScript-style XOR: converts operands to 32-bit signed, then XOR
  defp js_xor(a, b) do
    # Convert to 32-bit signed (like JS |0)
    a_32 = to_int32(a)
    b_32 = to_int32(b)
    # XOR and convert back to unsigned
    bxor(a_32, b_32) |> band(0xFFFFFFFF)
  end

  # Convert to 32-bit signed integer (like JS |0)
  defp to_int32(n) do
    n = band(n, 0xFFFFFFFF)
    if n >= 0x80000000, do: n - 0x100000000, else: n
  end

  # JavaScript-style multiplication for MurmurHash
  # In JS: (k & 0xffff) * m + ((((k >>> 16) * m) & 0xffff) << 16)
  # This can produce values > 32 bits, truncation happens on next bitwise op
  defp js_multiply(k, m) do
    # Ensure we start with 32-bit
    k = band(k, 0xFFFFFFFF)
    k_low = band(k, 0xFFFF)
    k_high = k >>> 16

    low_mult = k_low * m
    high_mult = k_high * m
    high_masked = band(high_mult, 0xFFFF)
    high_shifted = bsl(high_masked, 16)

    low_mult + high_shifted
  end

  @doc """
  Sorts pseudos matching StyleX's sortPseudos behavior exactly.

  StyleX's algorithm:
  - Pseudo-elements (::before, ::after) act as separators and stay in their original position
  - Pseudo-classes between pseudo-elements are grouped and sorted alphabetically
  - 'default' always comes first among pseudo-classes

  Examples:
  - `["::before", ":hover"]` → `["::before", ":hover"]` (pseudo-element first, then pseudo-class)
  - `[":hover", "::before"]` → `[":hover", "::before"]` (pseudo-class first, then pseudo-element)
  - `[":hover", ":active"]` → `[":active", ":hover"]` (sorted alphabetically)
  - `[":hover", "::before", ":active"]` → `[":hover", "::before", ":active"]` (each group kept/sorted)
  """
  @spec sort_pseudos(list(String.t())) :: list(String.t())
  def sort_pseudos(pseudos) when length(pseudos) < 2, do: pseudos

  def sort_pseudos(pseudos) do
    # StyleX's algorithm: pseudo-elements act as separators
    # Pseudo-classes between them are grouped and sorted
    pseudos
    |> Enum.reduce([], fn
      <<"::", _rest::binary>> = pseudo, acc ->
        # Pseudo-element: add directly to accumulator
        acc ++ [pseudo]

      pseudo, acc ->
        # Pseudo-class: add to the last group or create a new group
        case List.last(acc) do
          group when is_list(group) ->
            # Add to existing group
            List.replace_at(acc, -1, group ++ [pseudo])

          _ ->
            # Create new group
            acc ++ [[pseudo]]
        end
    end)
    |> Enum.flat_map(fn item ->
      if is_list(item) do
        # Sort pseudo-class groups alphabetically
        Enum.sort(item, &pseudo_comparator/2)
      else
        # Pseudo-elements stay as-is
        [item]
      end
    end)
  end

  # Comparator: 'default' comes first, otherwise alphabetical
  defp pseudo_comparator("default", _), do: true
  defp pseudo_comparator(_, "default"), do: false
  defp pseudo_comparator(a, b), do: a <= b

  @doc """
  Sorts at-rules alphabetically (matches StyleX's sortAtRules).
  """
  @spec sort_at_rules(list(String.t())) :: list(String.t())
  def sort_at_rules(at_rules), do: Enum.sort(at_rules)

  @doc """
  Splits a combined pseudo string into individual pseudos and sorts them.

  StyleX sorts pseudo-classes alphabetically when combined, but pseudo-elements
  stay in their original position. For example:
  - `:hover:active` becomes `:active:hover` (sorted alphabetically)
  - `::before:hover` stays as `::before:hover` (pseudo-element first, then pseudo-class)
  - `:hover::before:active` becomes `:hover::before:active` (pseudo-classes around pseudo-element are NOT merged)

  ## Examples

      iex> LiveStyle.Hash.sort_combined_pseudos(":hover:active")
      ":active:hover"

      iex> LiveStyle.Hash.sort_combined_pseudos("::before:hover")
      "::before:hover"
  """
  @spec sort_combined_pseudos(String.t() | nil) :: String.t() | nil
  def sort_combined_pseudos(nil), do: nil
  def sort_combined_pseudos(""), do: ""

  # Starts with pseudo-element
  def sort_combined_pseudos(<<"::", _rest::binary>> = combined) do
    # For ::before:hover, keep the pseudo-element first, then the pseudo-classes
    case Regex.run(Pseudo.element_split_regex(), combined) do
      [_, pseudo_element, rest] when rest != "" ->
        # Sort only the pseudo-classes that come after the pseudo-element
        sorted_rest = sort_pseudo_classes_only(rest)
        pseudo_element <> sorted_rest

      _ ->
        combined
    end
  end

  def sort_combined_pseudos(combined) when is_binary(combined) do
    # Don't sort complex selectors like :where(...), :is(...), :not(...), :has(...)
    # These contain parentheses and should be passed through unchanged
    if String.contains?(combined, "(") do
      combined
    else
      # Pure pseudo-classes: split and sort
      pseudos = split_pseudos(combined)

      pseudos
      |> sort_pseudos()
      |> Enum.join("")
    end
  end

  # Sort only pseudo-classes (not pseudo-elements) in a string
  defp sort_pseudo_classes_only(str) do
    pseudos = split_pseudos(str)

    # Separate pseudo-elements from pseudo-classes
    {pseudo_elements, pseudo_classes} =
      Enum.split_with(pseudos, &Pseudo.element?/1)

    # Sort pseudo-classes, keep pseudo-elements in order
    sorted_classes = Enum.sort(pseudo_classes, &pseudo_comparator/2)

    # Pseudo-elements stay at the end in original order (matching StyleX)
    (sorted_classes ++ pseudo_elements)
    |> Enum.join("")
  end

  # Split a combined pseudo string into individual pseudos
  # ":hover:active" -> [":hover", ":active"]
  # "::before:hover" -> ["::before", ":hover"]
  defp split_pseudos(combined) do
    # Handle pseudo-elements (::) vs pseudo-classes (:)
    # We need to split on : but preserve :: as a unit
    combined
    # Temporary placeholder for ::
    |> String.replace("::", "\x00\x00")
    |> String.split(":")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn part ->
      part = String.replace(part, "\x00\x00", "::")

      case part do
        <<"::", _rest::binary>> -> part
        _ -> ":" <> part
      end
    end)
  end
end
