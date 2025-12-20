defmodule LiveStyle.Selector.Prefixer do
  @moduledoc """
  Expands CSS selectors to include vendor-prefixed variants for cross-browser compatibility.

  This module handles selector prefixing for pseudo-elements and pseudo-classes that
  require vendor prefixes in different browsers. It mirrors the behavior of autoprefixer's
  selector hacks.

  ## Supported Selectors

  ### Pseudo-elements
  - `::thumb` → `::-webkit-slider-thumb`, `::-moz-range-thumb`, `::-ms-thumb`
  - `::placeholder` → `::-webkit-input-placeholder`, `::-moz-placeholder`, `:-ms-input-placeholder`
  - `::file-selector-button` → `::-webkit-file-upload-button`

  ### Pseudo-classes
  - `:fullscreen` → `:-webkit-full-screen`, `:-moz-full-screen`
  - `:autofill` → `:-webkit-autofill`
  - `:placeholder-shown` → `:-moz-placeholder-shown`

  ## Examples

      iex> LiveStyle.Selector.Prefixer.prefix(".btn::placeholder")
      ".btn::-webkit-input-placeholder, .btn::-moz-placeholder, .btn:-ms-input-placeholder, .btn::placeholder"

      iex> LiveStyle.Selector.Prefixer.prefix(".btn:fullscreen")
      ".btn:-webkit-full-screen, .btn:-moz-full-screen, .btn:fullscreen"

  ## Configuration

  Selector prefixing is always enabled. Unlike property prefixing which depends on
  browserslist configuration, selector prefixing provides maximum compatibility by
  default since the prefixed selectors don't add significant overhead.
  """

  alias LiveStyle.Data.Parser

  # Load selector expansions at compile time from data file
  @external_resource Parser.data_path("selector_expansions.txt")
  @selector_expansions Parser.selector_expansions()

  # Pre-compile the list of selectors we handle for fast checking
  @handled_selectors Map.keys(@selector_expansions)

  # Pre-compile a regex for fast matching
  @selector_pattern @handled_selectors
                    |> Enum.map_join("|", &Regex.escape/1)
                    |> then(&Regex.compile!("(#{&1})"))

  # Generate pattern-matched function clauses for variants_for/1
  for {selector, variants} <- @selector_expansions do
    defp do_variants_for(unquote(selector)), do: unquote(variants)
  end

  defp do_variants_for(_), do: nil

  @doc """
  Returns the map of selector expansions.

  Useful for introspection and testing.
  """
  @spec expansions() :: %{String.t() => [String.t()]}
  def expansions, do: @selector_expansions

  @doc """
  Returns the list of selectors that will be expanded.
  """
  @spec handled_selectors() :: [String.t()]
  def handled_selectors, do: @handled_selectors

  @doc """
  Expands a CSS selector to include vendor-prefixed variants.

  If the selector contains any of the handled pseudo-elements or pseudo-classes,
  it will be expanded to a comma-separated list of all variants.

  Selectors that don't need prefixing are returned unchanged.

  ## Examples

      iex> LiveStyle.Selector.Prefixer.prefix(".x123::thumb")
      ".x123::-webkit-slider-thumb, .x123::-moz-range-thumb, .x123::-ms-thumb"

      iex> LiveStyle.Selector.Prefixer.prefix(".x123::placeholder")
      ".x123::-webkit-input-placeholder, .x123::-moz-placeholder, .x123:-ms-input-placeholder, .x123::placeholder"

      iex> LiveStyle.Selector.Prefixer.prefix(".x123:hover")
      ".x123:hover"

      iex> LiveStyle.Selector.Prefixer.prefix(".x123:fullscreen")
      ".x123:-webkit-full-screen, .x123:-moz-full-screen, .x123:fullscreen"
  """
  @spec prefix(String.t()) :: String.t()
  def prefix(selector) do
    case find_expansion(selector) do
      nil -> selector
      {prefix, suffix, variants} -> expand_selector(selector, prefix, suffix, variants)
    end
  end

  @doc """
  Checks if a selector contains any pseudo-element or pseudo-class that needs prefixing.

  ## Examples

      iex> LiveStyle.Selector.Prefixer.needs_prefix?(".x123::placeholder")
      true

      iex> LiveStyle.Selector.Prefixer.needs_prefix?(".x123:hover")
      false
  """
  @spec needs_prefix?(String.t()) :: boolean()
  def needs_prefix?(selector) do
    Regex.match?(@selector_pattern, selector)
  end

  @doc """
  Returns the variants for a given pseudo-element or pseudo-class.

  Returns `nil` if the selector is not handled.

  ## Examples

      iex> LiveStyle.Selector.Prefixer.variants_for("::placeholder")
      ["::-webkit-input-placeholder", "::-moz-placeholder", ":-ms-input-placeholder", "::placeholder"]

      iex> LiveStyle.Selector.Prefixer.variants_for(":hover")
      nil
  """
  @spec variants_for(String.t()) :: [String.t()] | nil
  def variants_for(pseudo), do: do_variants_for(pseudo)

  # Find the first matching expansion pattern in the selector using regex
  # Returns {prefix, pattern, suffix, variants} for efficient expansion
  defp find_expansion(selector) do
    case Regex.run(@selector_pattern, selector, return: :index) do
      [{start, length}, _] ->
        pattern = binary_part(selector, start, length)
        prefix = binary_part(selector, 0, start)
        suffix = binary_part(selector, start + length, byte_size(selector) - start - length)
        {prefix, suffix, do_variants_for(pattern)}

      _ ->
        nil
    end
  end

  # Expand selector by concatenating prefix + variant + suffix
  # This is faster than repeated String.replace calls
  defp expand_selector(_selector, prefix, suffix, variants) do
    Enum.map_join(variants, ", ", fn variant ->
      prefix <> variant <> suffix
    end)
  end
end
