defmodule LiveStyle.Manifest.ViewTransitionClassEntry do
  @moduledoc """
  Entry structure for view transitions.
  """

  @type t :: [ident: String.t(), styles: keyword()]

  @doc """
  Creates a new view transition entry.

  ## Parameters

    * `ident` - The CSS class name (e.g., "x1abc123")
    * `styles` - The view transition styles (keyed by pseudo-element)

  ## Examples

      ViewTransitionClassEntry.new("x1abc123", [
        old: [animation_name: "fadeOut"],
        new: [animation_name: "fadeIn"]
      ])
  """
  @spec new(String.t(), keyword()) :: t()
  def new(ident, styles) do
    [ident: ident, styles: styles]
  end

  @doc """
  Gets the ident from a view transition entry.
  """
  @spec ident(t()) :: String.t()
  def ident(entry), do: Keyword.fetch!(entry, :ident)

  @doc """
  Gets the styles from a view transition entry.
  """
  @spec styles(t()) :: keyword()
  def styles(entry), do: Keyword.fetch!(entry, :styles)
end
