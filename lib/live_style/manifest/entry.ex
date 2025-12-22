defmodule LiveStyle.Manifest.Entry do
  @moduledoc false

  @spec put(LiveStyle.Manifest.t(), atom(), String.t(), term()) :: LiveStyle.Manifest.t()
  def put(manifest, section_key, entry_key, entry) when is_atom(section_key) do
    put_in(manifest, [section_key, entry_key], entry)
  end

  @spec get(LiveStyle.Manifest.t(), atom(), String.t()) :: term() | nil
  def get(manifest, section_key, entry_key) when is_atom(section_key) do
    get_in(manifest, [section_key, entry_key])
  end
end
