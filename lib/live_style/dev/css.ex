defmodule LiveStyle.Dev.CSS do
  @moduledoc false

  alias LiveStyle.Dev.Ensure
  alias LiveStyle.Manifest

  @spec css(module(), atom() | [atom()]) :: String.t()
  def css(module, ref_or_refs) when is_atom(module) do
    Ensure.ensure_live_style_module!(module)

    refs = List.wrap(ref_or_refs)
    manifest = LiveStyle.Storage.read()

    refs
    |> Enum.flat_map(fn ref ->
      key = Manifest.simple_key(module, ref)

      manifest
      |> Manifest.get_class(key)
      |> extract_ltr_css()
    end)
    |> Enum.join("")
  end

  defp extract_ltr_css(nil), do: []
  defp extract_ltr_css(%{atomic_classes: nil}), do: []

  defp extract_ltr_css(%{atomic_classes: atomic_classes}) when is_map(atomic_classes) do
    atomic_classes
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.flat_map(fn {_prop, meta} -> extract_ltr_from_meta(meta) end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ltr_css(_), do: []

  defp extract_ltr_from_meta(%{ltr: ltr}) when is_binary(ltr), do: [ltr]

  defp extract_ltr_from_meta(%{classes: classes}) when is_map(classes) do
    classes
    |> Map.values()
    |> Enum.map(fn
      %{ltr: ltr} when is_binary(ltr) -> ltr
      _ -> nil
    end)
  end

  defp extract_ltr_from_meta(_), do: []
end
