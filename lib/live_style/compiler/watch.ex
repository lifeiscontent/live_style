defmodule LiveStyle.Compiler.Watch do
  @moduledoc false

  @spec run_watch_mode(String.t(), String.t(), (String.t() -> non_neg_integer())) ::
          non_neg_integer()
  def run_watch_mode(output, manifest_path, run_once_fun) when is_function(run_once_fun, 1) do
    require Logger

    # Initial generation
    _ = run_once_fun.(output)

    manifest_dir = Path.dirname(manifest_path)

    unless Code.ensure_loaded?(FileSystem) do
      Logger.error("""
      LiveStyle watch mode requires the :file_system dependency.
      Add {:file_system, "~> 1.0"} to your deps or use phoenix_live_reload which includes it.
      """)

      return_error()
    end

    File.mkdir_p!(manifest_dir)

    {:ok, pid} = apply(FileSystem, :start_link, [[dirs: [manifest_dir]]])
    apply(FileSystem, :subscribe, [pid])

    Logger.info("LiveStyle watching for changes...")

    watch_loop(output, manifest_path, run_once_fun)
  end

  defp watch_loop(output, manifest_path, run_once_fun) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if Path.expand(path) == Path.expand(manifest_path) and
             Enum.any?(events, &(&1 in [:modified, :created])) do
          _ = run_once_fun.(output)
        end

        watch_loop(output, manifest_path, run_once_fun)

      {:file_event, _pid, :stop} ->
        0
    end
  end

  defp return_error, do: 1
end
