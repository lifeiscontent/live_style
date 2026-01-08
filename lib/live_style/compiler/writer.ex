defmodule LiveStyle.Compiler.Writer do
  @moduledoc false

  alias LiveStyle.Compiler.CSS
  alias LiveStyle.Compiler.CSS.Pipeline
  alias LiveStyle.Config
  alias LiveStyle.Storage

  @spec write_css(keyword()) :: :ok | {:error, term()}
  def write_css(opts \\ []) do
    output = Keyword.get(opts, :output_path, Config.output_path())
    log_fn = Keyword.get(opts, :log)

    manifest = Storage.read()

    case CSS.write(output, stats: true) do
      {:ok, :written} ->
        if log_fn do
          stats = Pipeline.stats(manifest)
          log_fn.({:written, stats, output})
        end

        :ok

      {:ok, :unchanged} ->
        if log_fn, do: log_fn.({:unchanged, output})
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

  defp log_run({:written, stats, output_path}) do
    require Logger

    Logger.info(
      "LiveStyle: #{stats[:vars]} vars, #{stats[:keyframes]} keyframes, #{stats[:classes]} rules → #{output_path}"
    )
  end

  defp log_run({:unchanged, output_path}) do
    require Logger
    Logger.debug("LiveStyle: CSS unchanged, skipping write → #{output_path}")
  end
end
