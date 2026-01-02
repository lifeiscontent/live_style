defmodule LiveStyle.Manifest.ThemeClassEntry do
  @moduledoc """
  Entry structure for theme variable overrides.
  """

  @type t :: [ident: String.t(), overrides: list()]

  @doc """
  Creates a new theme entry.

  ## Parameters

    * `ident` - The theme CSS class name (e.g., "x1abc123")
    * `overrides` - List of {var_ident, value} tuples

  ## Examples

      ThemeClassEntry.new("x1abc123", [{"--x-color-primary", "darkblue"}])
  """
  @spec new(String.t(), list()) :: t()
  def new(ident, overrides) do
    [ident: ident, overrides: overrides]
  end

  @doc """
  Gets the ident from a theme entry.
  """
  @spec ident(t()) :: String.t()
  def ident(entry), do: Keyword.fetch!(entry, :ident)

  @doc """
  Gets the overrides from a theme entry.
  """
  @spec overrides(t()) :: list()
  def overrides(entry), do: Keyword.fetch!(entry, :overrides)
end
