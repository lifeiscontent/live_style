defmodule LiveStyle.Dev.Ensure do
  @moduledoc false

  @spec ensure_live_style_module!(module()) :: :ok
  def ensure_live_style_module!(module) do
    unless Code.ensure_loaded?(module) and function_exported?(module, :__live_style__, 1) do
      raise ArgumentError, "#{inspect(module)} is not a LiveStyle module"
    end

    :ok
  end
end
