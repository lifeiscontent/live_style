defmodule LiveStyle.Utils do
  @moduledoc """
  Common utility functions shared across LiveStyle modules.
  """

  alias LiveStyle.Utils.{CSS, Normalize, Split}

  @doc """
  Normalizes a keyword list or map to a map.

  Accepts both maps (returned as-is) and keyword lists (converted to maps).
  This is commonly used to accept flexible input in macro APIs.
  """
  @spec normalize_to_map(map() | keyword()) :: map()
  defdelegate normalize_to_map(value), to: Normalize

  @doc """
  Formats CSS declarations as a minified string.

  Converts a map of property/value pairs to minified CSS format (prop:value;).
  Properties are sorted alphabetically for consistent output.
  """
  @spec format_declarations(map() | keyword()) :: String.t()
  defdelegate format_declarations(declarations), to: CSS

  @doc """
  Splits a CSS value string on whitespace, respecting parentheses nesting.

  This is used for parsing shorthand properties where values may contain
  functions like `rgb()`, `calc()`, etc.
  """
  @spec split_css_value(String.t()) :: [String.t()]
  defdelegate split_css_value(value), to: Split
end
