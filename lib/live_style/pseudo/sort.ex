defmodule LiveStyle.Pseudo.Sort do
  @moduledoc """
  Sorting functions for CSS pseudo-classes and pseudo-elements.

  This module implements StyleX-compatible sorting for pseudo selectors:
  - Pseudo-elements (`::before`, `::after`) act as separators and maintain position
  - Pseudo-classes between pseudo-elements are grouped and sorted alphabetically
  - `default` always comes first among pseudo-classes

  ## Examples

      iex> LiveStyle.Pseudo.Sort.sort([":hover", ":active"])
      [":active", ":hover"]

      iex> LiveStyle.Pseudo.Sort.sort_combined(":hover:active")
      ":active:hover"
  """

  # Compiled regex pattern for pseudo-element splitting
  @pseudo_element_split_regex ~r/^(::[\w-]+)(.*)$/

  @doc """
  Sorts pseudos matching StyleX's sortPseudos behavior exactly.

  StyleX's algorithm:
  - Pseudo-elements (::before, ::after) act as separators and stay in their original position
  - Pseudo-classes between pseudo-elements are grouped and sorted alphabetically
  - 'default' always comes first among pseudo-classes

  ## Examples

      iex> LiveStyle.Pseudo.Sort.sort([":hover", ":active"])
      [":active", ":hover"]

      iex> LiveStyle.Pseudo.Sort.sort(["::before", ":hover"])
      ["::before", ":hover"]

      iex> LiveStyle.Pseudo.Sort.sort([":hover", "::before", ":active"])
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

      iex> LiveStyle.Pseudo.Sort.sort_combined(":hover:active")
      ":active:hover"

      iex> LiveStyle.Pseudo.Sort.sort_combined("::before:hover")
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

      iex> LiveStyle.Pseudo.Sort.split(":hover:active")
      [":hover", ":active"]

      iex> LiveStyle.Pseudo.Sort.split("::before:hover")
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

  # Check if selector is a pseudo-element
  defp element?(<<"::", _rest::binary>>), do: true
  defp element?(_), do: false

  # Comparator: 'default' comes first, otherwise alphabetical
  defp sort_comparator("default", _), do: true
  defp sort_comparator(_, "default"), do: false
  defp sort_comparator(a, b), do: a <= b
end
