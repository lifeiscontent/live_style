defmodule LiveStyle.Manifest.Keys do
  @moduledoc false

  @spec namespaced_key(module(), atom(), atom()) :: String.t()
  def namespaced_key(module, namespace, name) do
    "#{inspect(module)}.#{namespace}.#{name}"
  end

  @spec simple_key(module(), atom()) :: String.t()
  def simple_key(module, name) do
    "#{inspect(module)}.#{name}"
  end
end
