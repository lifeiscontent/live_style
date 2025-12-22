defmodule LiveStyle.CSS.Keyframes do
  @moduledoc """
  CSS @keyframes generation for LiveStyle.

  This module handles generating @keyframes rules from the manifest,
  including RTL variants for animations that use logical properties.

  ## Output Format

  Keyframes are output in minified StyleX format:

      @keyframes xabc123-B{from{opacity:0;}to{opacity:1;}}

  RTL variants are wrapped in html[dir="rtl"]:

      html[dir="rtl"]{@keyframes xabc123-B{from{margin-right:0;}to{margin-right:10px;}}}
  """

  alias LiveStyle.Keyframes, as: KeyframesModule
  alias LiveStyle.Manifest
  alias LiveStyle.RTL
  alias LiveStyle.Value

  @doc """
  Generate @keyframes CSS from manifest.
  """
  @spec generate(Manifest.t()) :: String.t()
  def generate(manifest) do
    manifest.keyframes
    |> Enum.flat_map(fn {_key, entry} ->
      %{css_name: css_name, frames: frames} = entry

      # Generate LTR and RTL versions of each frame
      {ltr_frames, rtl_frames} = transform_frames_for_rtl(frames)

      ltr_css = build_css(css_name, ltr_frames)
      rtl_css = build_css(css_name, rtl_frames)

      # Only include RTL if it differs from LTR
      if ltr_css == rtl_css do
        [ltr_css]
      else
        [ltr_css, "html[dir=\"rtl\"]{#{rtl_css}}"]
      end
    end)
    |> Enum.join("\n")
  end

  # Transform keyframe declarations through RTL module
  defp transform_frames_for_rtl(frames) do
    ltr_frames = Enum.map(frames, &transform_frame_ltr/1)
    rtl_frames = Enum.map(frames, &transform_frame_rtl/1)
    {ltr_frames, rtl_frames}
  end

  defp transform_frame_ltr({selector, declarations}) do
    ltr_decls = Enum.map(declarations, &transform_decl_ltr/1)
    {selector, ltr_decls}
  end

  defp transform_decl_ltr({prop, val}) do
    css_prop = Value.to_css_property(prop)
    css_val = to_css_string(val)
    RTL.generate_ltr(css_prop, css_val)
  end

  defp transform_frame_rtl({selector, declarations}) do
    rtl_decls = Enum.map(declarations, &transform_decl_rtl/1)
    {selector, rtl_decls}
  end

  defp transform_decl_rtl({prop, val}) do
    css_prop = Value.to_css_property(prop)
    css_val = to_css_string(val)

    # Try to get RTL version, fall back to LTR if no RTL needed
    RTL.generate_rtl(css_prop, css_val) || RTL.generate_ltr(css_prop, css_val)
  end

  defp to_css_string(val) when is_binary(val), do: val
  defp to_css_string(val), do: to_string(val)

  # Build keyframes CSS in minified StyleX format
  # StyleX format: @keyframes name{from{color:red;}to{color:blue;}}
  defp build_css(css_name, frames) do
    frame_css =
      frames
      |> Enum.sort_by(fn {selector, _} -> frame_sort_key(selector) end)
      |> Enum.map_join("", fn {selector, declarations} ->
        selector_str = if is_atom(selector), do: to_string(selector), else: selector
        decl_str = format_declarations(declarations)
        "#{selector_str}{#{decl_str}}"
      end)

    "@keyframes #{css_name}{#{frame_css}}"
  end

  # Format keyframe declarations in minified format (prop:value;)
  defp format_declarations(declarations) do
    declarations
    |> Enum.map_join("", fn {prop, val} ->
      # `Value.to_css_property/1` already handles `var(--x)` used as a property key.
      css_prop = Value.to_css_property(prop)
      "#{css_prop}:#{val};"
    end)
  end

  # Sort keys for deterministic output, using shared frame_sort_order.
  # Returns tuple for stable sorting: {order, selector_string}
  defp frame_sort_key(selector) do
    selector_str = if is_atom(selector), do: to_string(selector), else: selector
    order = KeyframesModule.frame_sort_order(selector)
    {order, selector_str}
  end
end
