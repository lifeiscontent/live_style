defmodule LiveStyle.Manifest.VarEntry do
  @moduledoc """
  Entry structure for CSS custom properties (variables).
  """

  @type t :: [ident: String.t(), value: String.t() | list(), type: keyword() | nil]

  @doc """
  Creates a new var entry.

  ## Parameters

    * `ident` - The CSS variable identifier (e.g., "--x1abc123")
    * `value` - The variable value (string or list for conditional values)
    * `type` - Optional typed property info (syntax, initial, inherits)

  ## Examples

      VarEntry.new("--x1abc123", "blue")
      VarEntry.new("--x1abc123", "16px", [syntax: "<length>", initial: "0px", inherits: true])
  """
  @spec new(String.t(), String.t() | list(), keyword() | nil) :: t()
  def new(ident, value, type \\ nil) do
    [ident: ident, value: value, type: type]
  end

  @doc """
  Gets the ident from a var entry.
  """
  @spec ident(t()) :: String.t()
  def ident(entry), do: Keyword.fetch!(entry, :ident)

  @doc """
  Gets the value from a var entry.
  """
  @spec value(t()) :: String.t() | list()
  def value(entry), do: Keyword.fetch!(entry, :value)

  @doc """
  Gets the type info from a var entry.
  """
  @spec type(t()) :: keyword() | nil
  def type(entry), do: Keyword.get(entry, :type)
end
