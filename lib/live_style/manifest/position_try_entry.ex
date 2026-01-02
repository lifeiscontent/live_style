defmodule LiveStyle.Manifest.PositionTryEntry do
  @moduledoc """
  Entry structure for @position-try rules.
  """

  @type t :: [ident: String.t(), declarations: keyword()]

  @doc """
  Creates a new position-try entry.

  ## Parameters

    * `ident` - The CSS dashed-ident name (e.g., "--x1abc123")
    * `declarations` - The position-try declarations

  ## Examples

      PositionTryEntry.new("--x1abc123", [top: "anchor(bottom)", left: "anchor(left)"])
  """
  @spec new(String.t(), keyword()) :: t()
  def new(ident, declarations) do
    [ident: ident, declarations: declarations]
  end

  @doc """
  Gets the ident from a position-try entry.
  """
  @spec ident(t()) :: String.t()
  def ident(entry), do: Keyword.fetch!(entry, :ident)

  @doc """
  Gets the declarations from a position-try entry.
  """
  @spec declarations(t()) :: keyword()
  def declarations(entry), do: Keyword.fetch!(entry, :declarations)
end
