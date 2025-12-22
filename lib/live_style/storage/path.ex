defmodule LiveStyle.Storage.Path do
  @moduledoc false

  @default_path "_build/live_style_manifest.etf"
  @path_key :live_style_manifest_path

  @spec set_path(String.t()) :: :ok
  def set_path(path) when is_binary(path) do
    Process.put(@path_key, path)
    :ok
  end

  @spec clear_path() :: :ok
  def clear_path do
    Process.delete(@path_key)
    :ok
  end

  @spec path() :: String.t()
  def path do
    Process.get(@path_key) || Application.get_env(:live_style, :manifest_path, @default_path)
  end
end
