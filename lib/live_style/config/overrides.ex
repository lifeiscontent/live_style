defmodule LiveStyle.Config.Overrides do
  @moduledoc false

  @config_key :live_style_config_overrides

  @spec put(atom(), term()) :: :ok
  def put(key, value) do
    overrides = Process.get(@config_key, [])
    Process.put(@config_key, Keyword.put(overrides, key, value))
    :ok
  end

  @spec get(atom()) :: term() | nil
  def get(key) do
    overrides = Process.get(@config_key, [])
    Keyword.get(overrides, key)
  end

  @spec reset_all() :: :ok
  def reset_all do
    Process.delete(@config_key)
    :ok
  end

  @spec reset(atom()) :: :ok
  def reset(key) do
    overrides = Process.get(@config_key, [])
    Process.put(@config_key, Keyword.delete(overrides, key))
    :ok
  end

  @spec get_config(atom(), term()) :: term()
  def get_config(key, default) do
    case get(key) do
      nil -> Application.get_env(:live_style, key, default)
      value -> value
    end
  end
end
