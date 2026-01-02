defmodule LiveStyle.Manifest.KeyframesEntry do
  @moduledoc """
  Entry structure for @keyframes animations.
  """

  @type t :: [ident: String.t(), frames: list()]

  @doc """
  Creates a new keyframes entry.

  ## Parameters

    * `ident` - The CSS animation name (e.g., "x1abc123")
    * `frames` - The keyframe definitions

  ## Examples

      KeyframesEntry.new("x1abc123", ["0%": [opacity: 0], "100%": [opacity: 1]])
  """
  @spec new(String.t(), list()) :: t()
  def new(ident, frames) do
    [ident: ident, frames: frames]
  end

  @doc """
  Gets the ident from a keyframes entry.
  """
  @spec ident(t()) :: String.t()
  def ident(entry), do: Keyword.fetch!(entry, :ident)

  @doc """
  Gets the frames from a keyframes entry.
  """
  @spec frames(t()) :: list()
  def frames(entry), do: Keyword.fetch!(entry, :frames)
end
