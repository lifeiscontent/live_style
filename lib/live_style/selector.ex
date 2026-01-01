defmodule LiveStyle.Selector do
  @moduledoc false

  alias LiveStyle.Pseudo.Sort, as: PseudoSort
  alias LiveStyle.Selector.Prefixer, as: SelectorPrefixer

  # NOTE: This module exists to keep selector generation consistent between:
  # - LiveStyle.Compiler.CSS.AtomicRules (final CSS output)
  # - LiveStyle.Compiler.CSS.AtomicClass (class metadata generation)

  # -----------------
  # Atomic rules
  # -----------------

  @spec build_atomic_rule_selector(
          String.t(),
          String.t() | nil,
          String.t() | nil,
          String.t() | nil
        ) ::
          String.t()
  def build_atomic_rule_selector(class_name, selector_suffix, pseudo_element, at_rule) do
    use_layers = LiveStyle.Config.use_css_layers?()
    needs_bump = at_rule != nil or selector_suffix != nil
    # Sort pseudo-classes for deterministic output, but keep pseudo-elements as-is
    sorted_suffix = if selector_suffix, do: PseudoSort.sort_combined(selector_suffix), else: nil
    suffix = pseudo_element || sorted_suffix

    raw_selector =
      if needs_bump do
        build_bumped_selector(class_name, suffix, use_layers)
      else
        build_base_selector(class_name, suffix)
      end

    SelectorPrefixer.prefix(raw_selector)
  end

  defp build_base_selector(class_name, nil), do: ".#{class_name}"
  defp build_base_selector(class_name, suffix), do: ".#{class_name}#{suffix}"

  defp build_bumped_selector(class_name, suffix, true = _use_layers) do
    bumped = ".#{class_name}.#{class_name}"
    if suffix, do: "#{bumped}#{suffix}", else: bumped
  end

  defp build_bumped_selector(class_name, suffix, false = _use_layers) do
    bump = ":not(#\\#)"
    if suffix, do: ".#{class_name}#{bump}#{suffix}", else: ".#{class_name}#{bump}"
  end

  # -----------------
  # Atomic class metadata
  # -----------------

  @spec prefix_rtl(String.t()) :: String.t()
  def prefix_rtl(selector) do
    selector
    |> String.split(",")
    |> Enum.map_join(",", fn part ->
      "html[dir=\"rtl\"] " <> String.trim(part)
    end)
  end

  @spec build_atomic_class_selector(String.t(), String.t() | nil, String.t() | nil) :: String.t()
  def build_atomic_class_selector(class_name, selector_suffix, at_rule) do
    needs_specificity_bump = at_rule != nil or contextual_selector?(selector_suffix)

    base =
      if needs_specificity_bump do
        ".#{class_name}.#{class_name}"
      else
        ".#{class_name}"
      end

    if selector_suffix do
      sorted_suffix = PseudoSort.sort_combined(selector_suffix)
      "#{base}#{sorted_suffix}"
    else
      base
    end
  end

  @spec contextual_selector?(String.t() | nil) :: boolean()
  def contextual_selector?(nil), do: false

  def contextual_selector?(suffix) when is_binary(suffix) do
    String.starts_with?(suffix, ":where(") or
      String.starts_with?(suffix, ":is(") or
      String.starts_with?(suffix, ":has(") or
      (String.starts_with?(suffix, ":not(") and String.contains?(suffix, " "))
  end
end
