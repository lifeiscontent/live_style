defmodule LiveStyle.Compiler.Writer do
  @moduledoc false

  alias LiveStyle.Config

  @spec write_css(keyword()) :: :ok | {:error, term()}
  def write_css(opts \\ []) do
    output = Keyword.get(opts, :output_path, Config.output_path())
    log_fn = Keyword.get(opts, :log)

    manifest = LiveStyle.Storage.read()

    case LiveStyle.CSS.write(output, stats: true) do
      {:ok, :written} ->
        if log_fn do
          var_count = map_size(manifest.vars)
          keyframe_count = map_size(manifest.keyframes)
          class_count = map_size(manifest.classes)
          log_fn.({:written, var_count, keyframe_count, class_count, output})
        end

        :ok

      {:ok, :unchanged} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec run_once(String.t()) :: 0 | 1
  def run_once(output) do
    case write_css(output_path: output, log: &log_run/1) do
      :ok -> 0
      {:error, _reason} -> 1
    end
  end

  defp log_run({:written, var_count, keyframe_count, rule_count, output_path}) do
    require Logger

    Logger.info(
      "LiveStyle: #{var_count} vars, #{keyframe_count} keyframes, #{rule_count} rules → #{output_path}"
    )
  end
end
