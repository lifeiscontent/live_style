defmodule LiveStyle.Pseudo do
  @moduledoc """
  CSS pseudo-class and pseudo-element information and lookups.

  This module provides compile-time generated function clauses for efficient
  pseudo-class priority lookups, following the pattern used by the unicode library.

  All pseudo data is loaded from external files at compile time via
  `LiveStyle.Data`, enabling:
  - O(1) pattern-matched lookups instead of Map.get
  - Automatic recompilation when data files change
  - Single source of truth for pseudo metadata

  ## Pseudo-Class Priority System

  Pseudo-classes have priorities that determine their order in the cascade:
  - Lower priority pseudos are applied first
  - Higher priority pseudos override lower ones
  - `:hover` (130) < `:focus` (150) < `:active` (170)

  ## Pseudo-Element Priority

  Pseudo-elements (::before, ::after, etc.) add a base priority of 5000,
  which can be combined with pseudo-class priorities.

  ## Examples

      iex> LiveStyle.Pseudo.priority(":hover")
      130

      iex> LiveStyle.Pseudo.priority(":focus")
      150

      iex> LiveStyle.Pseudo.element_priority()
      5000
  """

  alias LiveStyle.Data

  @pseudo_class_priorities Data.pseudo_priorities()

  # Pseudo-element base priority (StyleX constant)
  @pseudo_element_priority 5000

  # Compiled regex patterns for pseudo parsing
  @pseudo_element_split_regex ~r/^(::[\w-]+)(.*)$/
  @pseudo_class_scan_regex ~r/:[a-z-]+(?:\([^)]*\))?/i
  @pseudo_base_regex ~r/^(:[a-z-]+)/
  @pseudo_extract_regex ~r/:(hover|focus|active|checked|focus-within|focus-visible)/

  @doc """
  Returns the priority of a single pseudo-class.

  Uses compile-time generated function clauses for O(1) pattern matching.

  ## Examples

      iex> LiveStyle.Pseudo.priority(":hover")
      130

      iex> LiveStyle.Pseudo.priority(":active")
      170

      iex> LiveStyle.Pseudo.priority(":unknown")
      40
  """
  @spec priority(String.t()) :: integer()

  # Generate function clauses for each pseudo-class in the data file
  for {pseudo, prio} <- @pseudo_class_priorities do
    def priority(unquote(pseudo)), do: unquote(prio)
  end

  # Default priority for unknown pseudo-classes
  def priority(_), do: 40

  @doc """
  Returns the base priority added for pseudo-elements.

  ## Examples

      iex> LiveStyle.Pseudo.element_priority()
      5000
  """
  @spec element_priority() :: integer()
  def element_priority, do: @pseudo_element_priority

  @doc """
  Calculate the total priority for a selector suffix.

  Handles:
  - Single pseudo-classes (`:hover`)
  - Combined pseudo-classes (`:hover:active`)
  - Pseudo-elements (`::before`)
  - Pseudo-elements with pseudo-classes (`::before:hover`)
  - Complex selectors (`:where(.marker:hover *)`)

  ## Examples

      iex> LiveStyle.Pseudo.calculate_priority(":hover")
      130

      iex> LiveStyle.Pseudo.calculate_priority(":hover:active")
      300

      iex> LiveStyle.Pseudo.calculate_priority("::before")
      5000

      iex> LiveStyle.Pseudo.calculate_priority("::before:hover")
      5130
  """
  @spec calculate_priority(String.t() | nil) :: integer()
  def calculate_priority(nil), do: 0

  # Pseudo-element (::before, ::after, etc.) - may have pseudo-classes after
  def calculate_priority(<<"::", _rest::binary>> = selector) do
    calculate_element_priority(selector)
  end

  # Pseudo-class(es) - may be combined like :hover:active
  def calculate_priority(<<":", _rest::binary>> = selector) do
    calculate_combined_priority(selector)
  end

  # Complex selector (e.g., :where(.marker:hover *))
  def calculate_priority(selector) when is_binary(selector) do
    extract_from_complex(selector)
  end

  # Handle pseudo-elements with optional pseudo-classes (e.g., ::before:hover)
  defp calculate_element_priority(selector) do
    case Regex.run(@pseudo_element_split_regex, selector) do
      [_, _pseudo_element, ""] ->
        @pseudo_element_priority

      [_, _pseudo_element, pseudo_classes] ->
        @pseudo_element_priority + calculate_combined_priority(pseudo_classes)

      _ ->
        @pseudo_element_priority
    end
  end

  # Sum priorities for all pseudo-classes in a combined selector like :hover:active
  defp calculate_combined_priority(selector) do
    selector
    |> split_pseudo_classes()
    |> Enum.reduce(0, fn pseudo, acc ->
      acc + get_single_priority(pseudo)
    end)
  end

  # Split a combined pseudo-class string into individual pseudo-classes
  # ":hover:active" -> [":hover", ":active"]
  defp split_pseudo_classes(selector) do
    @pseudo_class_scan_regex
    |> Regex.scan(selector)
    |> List.flatten()
  end

  # Get priority for a single pseudo-class, handling functional pseudos like :nth-child(2)
  defp get_single_priority(selector) do
    # Extract base pseudo from functional pseudo-classes like :nth-child(2)
    base_pseudo =
      case Regex.run(@pseudo_base_regex, selector) do
        [_, pseudo] -> pseudo
        _ -> selector
      end

    priority(base_pseudo)
  end

  # Extract pseudo-class from complex selector like :where(.marker:hover *)
  defp extract_from_complex(selector) do
    case Regex.run(@pseudo_extract_regex, selector) do
      [_, pseudo] -> priority(":#{pseudo}")
      _ -> 0
    end
  end

  @doc "Returns all pseudo-class priorities as a map."
  def priorities, do: @pseudo_class_priorities

  @doc "Returns the pseudo-element split regex pattern."
  def element_split_regex, do: @pseudo_element_split_regex

  @doc """
  Checks if the given selector is a pseudo-element (starts with ::).

  ## Examples

      iex> LiveStyle.Pseudo.element?("::before")
      true

      iex> LiveStyle.Pseudo.element?(":hover")
      false

      iex> LiveStyle.Pseudo.element?(nil)
      false
  """
  @spec element?(String.t() | atom() | nil) :: boolean()
  def element?(<<"::", _rest::binary>>), do: true
  def element?(key) when is_atom(key), do: element?(Atom.to_string(key))
  def element?(_), do: false

  # ============================================================================
  # Sorting Functions (StyleX-compatible)
  # ============================================================================

  @doc """
  Sorts pseudos matching StyleX's sortPseudos behavior exactly.

  StyleX's algorithm:
  - Pseudo-elements (::before, ::after) act as separators and stay in their original position
  - Pseudo-classes between pseudo-elements are grouped and sorted alphabetically
  - 'default' always comes first among pseudo-classes

  ## Examples

      iex> LiveStyle.Pseudo.sort([":hover", ":active"])
      [":active", ":hover"]

      iex> LiveStyle.Pseudo.sort(["::before", ":hover"])
      ["::before", ":hover"]

      iex> LiveStyle.Pseudo.sort([":hover", "::before", ":active"])
      [":hover", "::before", ":active"]
  """
  @spec sort(list(String.t())) :: list(String.t())
  def sort(pseudos) when length(pseudos) < 2, do: pseudos

  def sort(pseudos) do
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
        Enum.sort(item, &sort_comparator/2)
      else
        # Pseudo-elements stay as-is
        [item]
      end
    end)
  end

  @doc """
  Splits a combined pseudo string into individual pseudos and sorts them.

  StyleX sorts pseudo-classes alphabetically when combined, but pseudo-elements
  stay in their original position.

  ## Examples

      iex> LiveStyle.Pseudo.sort_combined(":hover:active")
      ":active:hover"

      iex> LiveStyle.Pseudo.sort_combined("::before:hover")
      "::before:hover"
  """
  @spec sort_combined(String.t() | nil) :: String.t() | nil
  def sort_combined(nil), do: nil
  def sort_combined(""), do: ""

  # Starts with pseudo-element
  def sort_combined(<<"::", _rest::binary>> = combined) do
    # For ::before:hover, keep the pseudo-element first, then the pseudo-classes
    case Regex.run(@pseudo_element_split_regex, combined) do
      [_, pseudo_element, rest] when rest != "" ->
        # Sort only the pseudo-classes that come after the pseudo-element
        sorted_rest = sort_classes_only(rest)
        pseudo_element <> sorted_rest

      _ ->
        combined
    end
  end

  def sort_combined(combined) when is_binary(combined) do
    # Don't sort complex selectors like :where(...), :is(...), :not(...), :has(...)
    # These contain parentheses and should be passed through unchanged
    if String.contains?(combined, "(") do
      combined
    else
      # Pure pseudo-classes: split and sort
      pseudos = split(combined)

      pseudos
      |> sort()
      |> Enum.join("")
    end
  end

  @doc """
  Splits a combined pseudo string into individual pseudos.

  ## Examples

      iex> LiveStyle.Pseudo.split(":hover:active")
      [":hover", ":active"]

      iex> LiveStyle.Pseudo.split("::before:hover")
      ["::before", ":hover"]
  """
  @spec split(String.t()) :: list(String.t())
  def split(combined) do
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

  # Sort only pseudo-classes (not pseudo-elements) in a string
  defp sort_classes_only(str) do
    pseudos = split(str)

    # Separate pseudo-elements from pseudo-classes
    {pseudo_elements, pseudo_classes} = Enum.split_with(pseudos, &element?/1)

    # Sort pseudo-classes, keep pseudo-elements in order
    sorted_classes = Enum.sort(pseudo_classes, &sort_comparator/2)

    # Pseudo-elements stay at the end in original order (matching StyleX)
    (sorted_classes ++ pseudo_elements)
    |> Enum.join("")
  end

  # Comparator: 'default' comes first, otherwise alphabetical
  defp sort_comparator("default", _), do: true
  defp sort_comparator(_, "default"), do: false
  defp sort_comparator(a, b), do: a <= b
end
