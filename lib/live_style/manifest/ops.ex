defmodule LiveStyle.Manifest.Ops do
  @moduledoc false

  @spec empty() :: LiveStyle.Manifest.t()
  def empty do
    %{
      vars: %{},
      consts: %{},
      keyframes: %{},
      position_try: %{},
      view_transitions: %{},
      classes: %{},
      themes: %{}
    }
  end

  @spec ensure_keys(term()) :: LiveStyle.Manifest.t()
  def ensure_keys(manifest) when is_map(manifest) do
    empty()
    |> Map.merge(manifest)
  end

  def ensure_keys(_manifest), do: empty()

  @spec has_styles?(LiveStyle.Manifest.t()) :: boolean()
  def has_styles?(manifest) do
    has_entries?(manifest, :vars) or
      has_entries?(manifest, :keyframes) or
      has_entries?(manifest, :classes) or
      has_entries?(manifest, :position_try) or
      has_entries?(manifest, :view_transitions) or
      has_entries?(manifest, :themes)
  end

  defp has_entries?(manifest, key) do
    map_size(Map.get(manifest, key, %{})) > 0
  end
end
