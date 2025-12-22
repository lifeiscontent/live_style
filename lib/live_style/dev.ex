defmodule LiveStyle.Dev do
  @moduledoc """
  Development helpers for inspecting and debugging LiveStyle classes.

  These functions are designed for use in IEx during development.

  ## Examples

      iex> LiveStyle.Dev.class_info(MyComponent, :button)
      %{name: :button, class: "...", css: "...", properties: %{...}, dynamic?: false}

      iex> LiveStyle.Dev.list(MyComponent)
      [:button, :primary, :secondary]

      iex> LiveStyle.Dev.diff(MyComponent, [:button, :primary])
      %{merged_class: "...", properties: %{...}}

      iex> LiveStyle.Dev.tokens(MyApp.Tokens)
      %{vars: %{...}, consts: %{...}, keyframes: [...], themes: [...]}
  """

  alias LiveStyle.Dev.{ClassInfo, CSS, Diff, List, Pretty, Tokens}

  def class_info(module, class_name), do: ClassInfo.class_info(module, class_name)

  def list(module, filter \\ :all), do: List.list(module, filter)

  def diff(module, refs), do: Diff.diff(module, refs)

  def tokens(module), do: Tokens.tokens(module)

  def css(module, ref_or_refs), do: CSS.css(module, ref_or_refs)

  def pp(module, class_name), do: Pretty.pp(module, class_name)

  def pp_list(module), do: Pretty.pp_list(module)
end
