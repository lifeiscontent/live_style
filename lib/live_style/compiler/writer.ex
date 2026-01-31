defmodule LiveStyle.Compiler.Writer do
  @moduledoc false

  alias LiveStyle.Compiler.CSS
  alias LiveStyle.Compiler.CSS.Pipeline
  alias LiveStyle.Config
  alias LiveStyle.Storage

  @spec write_css(keyword()) :: :ok | {:error, term()}
  def write_css(opts \\ []) do
    output = Keyword.get(opts, :output_path, Config.output_path())
    input = Keyword.get(opts, :input_path)
    log_fn = Keyword.get(opts, :log)

    manifest = Storage.read()

    write_opts = [stats: true] ++ if(input, do: [input: input], else: [])

    case CSS.write(output, write_opts) do
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

  @doc """
  Runs CSS generation once and writes to output.

  ## Parameters

    * `output` - Path to write the CSS output
    * `input` - Optional input file path with `@import "live_style"` directive
  """
  @spec run_once(String.t(), String.t() | nil) :: 0 | 1
  def run_once(output, input \\ nil) do
    opts = [output_path: output, log: &log_run/1] ++ if(input, do: [input_path: input], else: [])

    case write_css(opts) do
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
